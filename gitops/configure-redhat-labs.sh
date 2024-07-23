#!/bin/bash
set -x 

# Constants
DEFAULT_STORAGE_CLASS_NAME="ocs-storagecluster-ceph-rbd"
REPO_URL="https://github.com/tosin2013/sno-quickstarts.git"
KUSTOMIZE_INSTALL_SCRIPT="https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"

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
    ;;
  --configure-storage )
    CONFIGURE_STORAGE=true
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
    while [[ $(oc get pods $1 -n $2 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
        sleep 1
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
    # Check if the ArgoCD repo server pod is in a ready state
    local pod_ready=$(oc get pods -l app.kubernetes.io/name=openshift-gitops-repo-server -n openshift-gitops -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep True)

    if [ "$pod_ready" == "True" ]; then
        echo "ArgoCD is already running. Skipping configuration."
        return
    fi

    echo "Configuring ArgoCD..."
    oc create namespace openshift-gitops 2>/dev/null || true
    oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-gitops"

    # Wait for ArgoCD CRDs to be ready
    echo "Waiting for ArgoCD CRDs to be available..."
    until oc get crd/argocds.argoproj.io &> /dev/null; do
        echo "Waiting for ArgoCD CRDs to become available..."
        sleep 10
    done
    echo "ArgoCD CRDs are available."

    # Apply ArgoCD Configuration
    oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-gitops"
    local pod_name=$(oc get pods -n openshift-gitops | grep openshift-gitops-repo-server | awk '{print $1}')
    wait_for_pod "$pod_name" "openshift-gitops"
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
    oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-local-storage/operator/overlays/stable-4.16"
    oc apply -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-data-foundation-operator/operator/overlays/stable-4.16"
    echo "Waiting for ODF Operator to be ready..."
    echo "sleeping for 25s..."
    sleep 25s
    pod_name=$(oc get pods -n openshift-local-storage | grep local-storage-operator- | awk '{print $1}')
    wait_for_pod "$pod_name" "openshift-local-storage"
    local pod_name=$(oc get pods -n openshift-storage | grep ocs-operator | awk '{print $1}')
    wait_for_pod "$pod_name" "openshift-storage"
    oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-local-storage/instance/overlays/demo-redhat"
    oc create -k "$HOME/sno-quickstarts/gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/equinix-cnv"
}

# Configuration Checks and Setup
configure_argocd
[ "$CONFIGURE_INFRA_NODES" = true ] && configure_infranodes
[ "$CONFIGURE_STORAGE" = true ] && configure_storage
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