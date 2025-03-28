#!/bin/bash
set -x 

# Constants
DEFAULT_STORAGE_CLASS_NAME="ocs-storagecluster-ceph-rbd"
REPO_URL="https://github.com/tosin2013/sno-quickstarts.git"
KUSTOMIZE_INSTALL_SCRIPT="https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
MAX_RETRIES=3
TIMEOUT=300  # 5 minutes timeout for operations
DEBUG=true   # Enable debug output

# Debug function for logging
debug_log() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

# Print script usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --configure-infra-nodes    Configure infra nodes"
    echo "  --configure-storage        Configure storage"
    echo "  -h, --help                 Display this help and exit"
}

# Parse command line options
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  --configure-infra-nodes )
    CONFIGURE_INFRA_NODES=true
    debug_log "Infra nodes configuration enabled"
    ;;
  --configure-storage )
    CONFIGURE_STORAGE=true
    debug_log "Storage configuration enabled"
    ;;
  -h | --help )
    usage
    exit
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

# Check if logged in to OpenShift
if ! oc whoami &> /dev/null; then
    echo "Not logged in to OpenShift. Exiting..."
    exit 1
fi

# Helper function to wait for Pods to become Ready
wait_for_pod() {
    local pod_pattern=$1
    local namespace=$2
    local timeout=${3:-300}  # Default timeout of 5 minutes
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    echo "Waiting for pod matching '$pod_pattern' in namespace '$namespace' to be ready (timeout: ${timeout}s)..."
    
    while true; do
        local current_time=$(date +%s)
        if [[ $current_time -gt $end_time ]]; then
            echo "Timeout waiting for pod matching '$pod_pattern' in namespace '$namespace'"
            return 1
        fi
        
        # Get the pod name
        local pod_name=$(oc get pods -n $namespace | grep "$pod_pattern" | awk '{print $1}' | head -1)
        
        # If pod doesn't exist yet, wait and try again
        if [[ -z "$pod_name" ]]; then
            echo "Pod matching '$pod_pattern' not found in namespace '$namespace'. Waiting..."
            sleep 10
            continue
        fi
        
        # Check if pod is ready
        local ready_status=$(oc get pod $pod_name -n $namespace -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}')
        
        if [[ "$ready_status" == "True" ]]; then
            echo "Pod '$pod_name' in namespace '$namespace' is ready."
            return 0
        fi
        
        echo "Waiting for pod '$pod_name' in namespace '$namespace' to be ready..."
        sleep 10
    done
}

# Clone necessary Git repository if it doesn't exist
if [ ! -d "$HOME/sno-quickstarts" ]; then
    git clone $REPO_URL "$HOME/sno-quickstarts"
fi

# Install Kustomize if not already installed
if [ ! -f /usr/local/bin/kustomize ]; then
    curl -s "$KUSTOMIZE_INSTALL_SCRIPT" | bash
    sudo mv kustomize /usr/local/bin
fi

# Configuration functions
configure_argocd() {
    echo "Checking if ArgoCD is already running..."
    
    # First check if namespace exists
    if oc get namespace openshift-gitops &>/dev/null; then
        # Check if the ArgoCD repo server pod exists and is in a ready state
        if oc get pods -l app.kubernetes.io/name=openshift-gitops-repo-server -n openshift-gitops &>/dev/null; then
            local pod_ready=$(oc get pods -l app.kubernetes.io/name=openshift-gitops-repo-server -n openshift-gitops -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep True)
            
            if [ "$pod_ready" == "True" ]; then
                echo "ArgoCD is already running and ready. Skipping configuration."
                return 0
            fi
        fi
    fi

    echo "Configuring ArgoCD..."
    
    # Create namespace if it doesn't exist
    if ! oc get namespace openshift-gitops &>/dev/null; then
        echo "Creating openshift-gitops namespace..."
        oc create namespace openshift-gitops || {
            echo "Failed to create openshift-gitops namespace. Exiting."
            return 1
        }
    fi
    
    # Apply initial configuration
    echo "Applying initial GitOps configuration..."
    oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-gitops" || {
        echo "Failed to apply initial GitOps configuration. Retrying..."
        sleep 5
        oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-gitops" || {
            echo "Failed to apply initial GitOps configuration after retry. Exiting."
            return 1
        }
    }

    # Wait for ArgoCD CRDs to be ready with timeout
    echo "Waiting for ArgoCD CRDs to be available..."
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local crd_ready=false
    
    while [[ $(date +%s) -lt $end_time ]]; do
        if oc get crd/argocds.argoproj.io &> /dev/null; then
            echo "ArgoCD CRDs are available."
            crd_ready=true
            break
        fi
        echo "Waiting for ArgoCD CRDs to become available..."
        sleep 10
    done
    
    if [ "$crd_ready" != "true" ]; then
        echo "Timeout waiting for ArgoCD CRDs. Exiting."
        return 1
    fi

    # Apply full ArgoCD Configuration
    echo "Applying full ArgoCD configuration..."
    oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-gitops" || {
        echo "Failed to apply full GitOps configuration. Retrying..."
        sleep 5
        oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-gitops" || {
            echo "Failed to apply full GitOps configuration after retry. Exiting."
            return 1
        }
    }
    
    # Wait for repo server pod to be ready
    echo "Waiting for ArgoCD repo server pod to be ready..."
    if ! wait_for_pod "openshift-gitops-repo-server" "openshift-gitops" $TIMEOUT; then
        echo "Timeout waiting for ArgoCD repo server pod. Installation may be incomplete."
        return 1
    fi
    
    echo "ArgoCD configuration completed successfully."
    return 0
}


configure_infranodes() {
    local nodes=("lab-worker-0" "lab-worker-1" "lab-worker-2")
    for node in "${nodes[@]}"; do
        oc label node "$node" node-role.kubernetes.io/infra=""
        oc label node "$node" cluster.ocs.openshift.io/openshift-storage=""
    done
    oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra": ""}}}'
    oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}}'
}

configure_storage() {
    echo "Configuring OpenShift Local Storage and Data Foundation..."
    
    # Check if storage is already configured
    if oc get localvolumeset -n openshift-local-storage &>/dev/null && oc get storagecluster -n openshift-storage &>/dev/null; then
        echo "Storage appears to be already configured. Checking status..."
        
        # Verify storage cluster status
        local storage_status=$(oc get storagecluster -n openshift-storage -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        if [[ "$storage_status" == "Ready" ]]; then
            echo "Storage cluster is already configured and ready. Skipping configuration."
            return 0
        else
            echo "Storage cluster exists but is not in Ready state (current state: $storage_status). Will attempt to reconfigure."
        fi
    fi
    
    # Apply local storage operator
    echo "Applying OpenShift Local Storage Operator..."
    oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-local-storage/operator/overlays/stable-4.17" || {
        echo "Failed to apply Local Storage Operator. Retrying..."
        sleep 5
        oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-local-storage/operator/overlays/stable-4.17" || {
            echo "Failed to apply Local Storage Operator after retry. Exiting."
            return 1
        }
    }
    
    # Apply ODF operator
    echo "Applying OpenShift Data Foundation Operator..."
    oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-data-foundation-operator/operator/overlays/stable-4.17" || {
        echo "Failed to apply Data Foundation Operator. Retrying..."
        sleep 5
        oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-data-foundation-operator/operator/overlays/stable-4.17" || {
            echo "Failed to apply Data Foundation Operator after retry. Exiting."
            return 1
        }
    }
    
    echo "Waiting for operators to be installed..."
    echo "This may take a few minutes..."
    
    # Wait for local storage operator namespace to be created
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local namespace_ready=false
    
    echo "Waiting for openshift-local-storage namespace to be available..."
    while [[ $(date +%s) -lt $end_time ]]; do
        if oc get namespace openshift-local-storage &>/dev/null; then
            namespace_ready=true
            break
        fi
        echo "Waiting for openshift-local-storage namespace..."
        sleep 10
    done
    
    if [[ "$namespace_ready" != "true" ]]; then
        echo "Timeout waiting for openshift-local-storage namespace. Exiting."
        return 1
    fi
    
    # Wait for ODF operator namespace to be created
    namespace_ready=false
    echo "Waiting for openshift-storage namespace to be available..."
    while [[ $(date +%s) -lt $end_time ]]; do
        if oc get namespace openshift-storage &>/dev/null; then
            namespace_ready=true
            break
        fi
        echo "Waiting for openshift-storage namespace..."
        sleep 10
    done
    
    if [[ "$namespace_ready" != "true" ]]; then
        echo "Timeout waiting for openshift-storage namespace. Exiting."
        return 1
    fi
    
    # Wait for local storage operator pod
    echo "Waiting for Local Storage Operator pod to be ready..."
    if ! wait_for_pod "local-storage-operator" "openshift-local-storage" $TIMEOUT; then
        echo "Timeout waiting for Local Storage Operator pod. Installation may be incomplete."
        return 1
    fi
    
    # Wait for ODF operator pod
    echo "Waiting for ODF Operator pod to be ready..."
    if ! wait_for_pod "ocs-operator" "openshift-storage" $TIMEOUT; then
        echo "Timeout waiting for ODF Operator pod. Installation may be incomplete."
        return 1
    fi
    
    # Create local storage instance
    echo "Creating Local Storage instance..."
    oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-local-storage/instance/overlays/demo-redhat" || {
        echo "Failed to create Local Storage instance. Retrying..."
        sleep 5
        oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-local-storage/instance/overlays/demo-redhat" || {
            echo "Failed to create Local Storage instance after retry. Exiting."
            return 1
        }
    }
    
    # Wait for local volume discovery to complete
    echo "Waiting for local volume discovery to complete..."
    sleep 30
    
    # Create ODF instance
    echo "Creating OpenShift Data Foundation instance..."
    oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/equinix-cnv" || {
        echo "Failed to create ODF instance. Retrying..."
        sleep 5
        oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/equinix-cnv" || {
            echo "Failed to create ODF instance after retry. Exiting."
            return 1
        }
    }
    
    # Verify storage cluster creation
    echo "Verifying storage cluster creation..."
    local verify_start_time=$(date +%s)
    local verify_end_time=$((verify_start_time + 300)) # 5 minute timeout for verification
    local storage_cluster_created=false
    
    while [[ $(date +%s) -lt $verify_end_time ]]; do
        if oc get storagecluster -n openshift-storage &>/dev/null; then
            storage_cluster_created=true
            echo "Storage cluster created successfully."
            break
        fi
        echo "Waiting for storage cluster to be created..."
        sleep 20
    done
    
    if [[ "$storage_cluster_created" != "true" ]]; then
        echo "Timeout waiting for storage cluster to be created. Please check the status manually."
        return 1
    fi
    
    echo "Storage configuration completed successfully."
    echo "Note: The storage cluster may take several minutes to become fully ready."
    echo "You can check the status with: oc get storagecluster -n openshift-storage"
    return 0
}

# Configuration Checks and Setup
debug_log "Starting configuration process"
debug_log "ArgoCD configuration is always enabled"
configure_argocd || {
    echo "ERROR: ArgoCD configuration failed. Exiting."
    exit 1
}

if [[ "$CONFIGURE_INFRA_NODES" == "true" ]]; then
    debug_log "Executing infra nodes configuration"
    configure_infranodes || {
        echo "ERROR: Infra nodes configuration failed. Exiting."
        exit 1
    }
    debug_log "Infra nodes configuration completed successfully"
else
    debug_log "Skipping infra nodes configuration (flag not set)"
fi

if [[ "$CONFIGURE_STORAGE" == "true" ]]; then
    debug_log "Executing storage configuration"
    configure_storage || {
        echo "ERROR: Storage configuration failed. Exiting."
        exit 1
    }
    
    # Verify storage configuration was successful
    debug_log "Verifying storage configuration"
    if oc get storagecluster -n openshift-storage &>/dev/null; then
        echo "✅ Storage configuration verified: StorageCluster exists in openshift-storage namespace"
    else
        echo "⚠️ Storage configuration verification failed: StorageCluster not found in openshift-storage namespace"
        echo "Please check the logs above for errors"
    fi
    
    if oc get localvolumeset -n openshift-local-storage &>/dev/null; then
        echo "✅ Storage configuration verified: LocalVolumeSet exists in openshift-local-storage namespace"
    else
        echo "⚠️ Storage configuration verification failed: LocalVolumeSet not found in openshift-local-storage namespace"
        echo "Please check the logs above for errors"
    fi
    
    debug_log "Storage configuration process completed"
else
    debug_log "Skipping storage configuration (flag not set)"
fi

#[ "$CONFIGURE_REGISTRY" = true ] && configure_registry

# User interaction for applying configurations
cd "$HOME/sno-quickstarts/gitops/apps"
options=("Exit" $(find . -maxdepth 1 -type d -not -path '.'))
select dir in "${options[@]}"; do
    case "$dir" in
        "Exit")
            echo "Exiting..."
            break
            ;;
        *)
            dir=${dir#./}
            echo "Applying configuration in $dir..."
            oc apply -f "$dir/cluster-config.yaml"
            ;;
    esac
done