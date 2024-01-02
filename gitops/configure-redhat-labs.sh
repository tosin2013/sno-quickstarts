#!/bin/bash 

if [ ! -f $HOME/sno-quickstarts ];
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
    while [[ $(oc get pods $1  -n openshift-storage -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
        sleep 1
    done

}

function configure_argocd(){
    oc create namespace openshift-gitops
    oc create -f init/
}


function configure_storage(){
    oc apply -k gitops/cluster-config/openshift-local-storage/operator/overlays/stable-4.14
    oc apply -k gitops/cluster-config/openshift-data-foundation-operator/operator/overlays/stable-4.14
    sleep 10s 

    PODNANE=$(oc get pods -n openshift-storage | grep ocs-operator | awk '{print $1}')
    wait-for-me $PODNANE


    PODNANE=$(oc get pods -n openshift-storage | grep lvm-operator-controller-manager | awk '{print $1}')
    wait-for-me $PODNANE


    oc create -k gitops/cluster-config/openshift-local-storage/instance/overlays/demo-redhat
    oc create -k gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/equinix-cnv
}

configure_storage

function configure_registry(){
    oc create -k  gitops/cluster-config/openshift-image-registry/overlays/vsphere
}

configure_registry

oc create -k gitops/cluster-config/openshift-gitops

