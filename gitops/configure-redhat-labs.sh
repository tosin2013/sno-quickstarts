#!/bin/bash 

CONFIGURE_INFRA_NODES=true
CONFIGURE_STORAGE=false
CONFIGURE_REGISTRY=false
DEFAULT_STORAGE_CLASS_NAME="ocs-storagecluster-ceph-rbd"

if ! oc whoami &> /dev/null; then
    echo "Not logged in to OpenShift. Exiting..."
    exit 1
fi

if [ ! -d $HOME/sno-quickstarts ];
then 
    cd $HOME
    git clone https://github.com/tosin2013/sno-quickstarts.git
fi 

if [ ! -f /usr/local/bin/kustomize ];
then 
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
    sudo mv kustomize /usr/local/bin
    kustomize
fi

cd $HOME/sno-quickstarts/


function wait-for-me(){
    while [[ $(oc get pods $1  -n $2 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
        sleep 1
    done

}

function configure_argocd(){
    echo "Configuring ArgoCD"
    oc create namespace openshift-gitops
    oc create -k $HOME/sno-quickstarts/gitops/cluster-config/openshift-gitops || exit $?
    sleep 30s
    oc apply -k $HOME/sno-quickstarts/gitopscluster-config/openshift-gitops
    PODNAME=$(oc get pods -n openshift-gitops | grep openshift-gitops-repo-server | awk '{print $1}')
    wait-for-me ${PODNAME} openshift-gitops
}
if ! oc get ns openshift-gitops &> /dev/null; then
    configure_argocd
fi

function configure_infranodes(){

    array=( lab-worker-0 lab-worker-1 lab-worker-2 )
    for i in "${array[@]}"
    do
        echo "$i"
        oc label node $i node-role.kubernetes.io/infra=""
        oc label node $i cluster.ocs.openshift.io/openshift-storage=""
        #oc adm taint node $i node.ocs.openshift.io/storage="true":NoSchedule # if you only want these nodes to run storage pods
    done

    oc patch configs.imageregistry.operator.openshift.io/cluster -p '{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra": ""}}}' --type=merge
    oc patch ingresscontroller/default -n  openshift-ingress-operator  --type=merge -p '{"spec":{"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}}'
    oc patch -n openshift-ingress-operator ingresscontroller/default --patch '{"spec":{"replicas": 3}}' --type=merge
}

if [ "$CONFIGURE_INFRA_NODES" = true ] ; then
    configure_infranodes
fi

function configure_storage(){
    oc apply -k gitops/cluster-config/openshift-local-storage/operator/overlays/stable-4.15
    oc apply -k gitops/cluster-config/openshift-data-foundation-operator/operator/overlays/stable-4.15
    sleep 10s 

    PODNANE=$(oc get pods -n openshift-storage | grep ocs-operator | awk '{print $1}')
    wait-for-me $PODNANE openshift-storage


    PODNANE=$(oc get pods -n openshift-local-storage | grep local-storage-operator- | awk '{print $1}')
    wait-for-me $PODNANE openshift-local-storage

    oc create -k gitops/cluster-config/openshift-local-storage/instance/overlays/demo-redhat
    oc create -k gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/equinix-cnv
}

if [ "$CONFIGURE_STORAGE" = true ] ; then
    configure_storage
    if [ -z "$DEFAULT_STORAGE_CLASS_NAME" ]; then
        oc patch storageclass ocs-storagecluster-ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    else 
        oc patch storageclass ocs-storagecluster-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
fi

function configure_registry(){
    oc create -k  gitops/cluster-config/openshift-image-registry/overlays/default
}
if [ "$CONFIGURE_REGISTRY" = true ] ; then
    configure_registry
fi


# Change to the directory where the YAML files are located
cd $HOME/sno-quickstarts/gitops/apps

# Get a list of directories
dirs=$(find . -maxdepth 1 -type d -not -path '.')

# Create a menu for the user to select from
select dir in $dirs; do
    if [ -n "$dir" ]; then
        # Remove './' from the beginning of the $dir variable
        dir=${dir#./}
        echo "Applying configuration in $dir..."
        
        # Run 'oc apply -f' on the YAML file in the selected directory
        echo "Deploying $dir..." 
        oc apply -f "$dir/cluster-config.yaml"
    else
        echo "Invalid selection, please try again."
    fi
done


