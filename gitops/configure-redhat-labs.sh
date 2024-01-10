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


    PODNANE=$(oc get pods -n openshift-local-storage | grep local-storage-operator- | awk '{print $1}')
    wait-for-me $PODNANE


    array=( lab-worker-0 lab-worker-1 lab-worker-2 )
    for i in "${array[@]}"
    do
        echo "$i"
        oc label node $i node-role.kubernetes.io/infra=""
        oc label node $i cluster.ocs.openshift.io/openshift-storage=""
        #oc adm taint node $i node.ocs.openshift.io/storage="true":NoSchedule # if you only want these nodes to run storage pods
    done

    oc patch configs.imageregistry.operator.openshift.io/cluster -p '{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra": ""}}}' --type=merge
    oc patch -n openshift-ingress-operator ingresscontroller/default --patch '{"spec":{"replicas": 3}}' --type=merge

    oc create -k gitops/cluster-config/openshift-local-storage/instance/overlays/demo-redhat
    oc create -k gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/equinix-cnv
}

configure_storage

function configure_registry(){
    oc create -k  gitops/cluster-config/openshift-image-registry/overlays/default
}


# oc patch storageclass ocs-storagecluster-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
# oc patch storageclass ocs-storagecluster-ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

configure_registry

oc create -k gitops/cluster-config/openshift-gitops

