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


function configure_sno_storage(){
    oc apply -k gitops/cluster-config/openshift-data-foundation-operator/operator/overlays/stable-4.11
    oc create -k gitops/cluster-config/odf-lvm-operator/operator/overlay/stable-4.11
    sleep 10s 

    PODNANE=$(oc get pods -n openshift-storage | grep ocs-operator | awk '{print $1}')
    wait-for-me $PODNANE


    PODNANE=$(oc get pods -n openshift-storage | grep lvm-operator-controller-manager | awk '{print $1}')
    wait-for-me $PODNANE


    oc create -k gitops/cluster-config/odf-lvm-operator/instance/overlay
    oc create -k gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/sno
}

configure_sno_storage

function configure_registry(){
    oc create -k  gitops/cluster-config/openshift-image-registry/overlays/vsphere
}

function acm_deployment()
{
    oc create -k  gitops/cluster-config/rhacm-operator/base
    oc create -k  gitops/cluster-config/rhacm-instance/overlays/basic
}



git clone https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable.git
cd ~/ztp-pipeline-relocatable/
export KUBECONFIG=/root/ztp-pipeline-relocatable/kubeconfig 
./pipelines/bootstrap.sh 
sed -i 's/odf-lvm-vg1/odf-lvm-vgmcg/g' deploy-lvmo/manifests/05-Hub-PVC.yaml
oc create -f ./deploy-lvmo/manifests/05-Hub-PVC.yaml -n edgecluster-deployer

cat >edgeclusters.yaml<<EOF
config:
  OC_OCP_VERSION: "4.11.21" 
  OC_ACM_VERSION: "2.6" 
  OC_ODF_VERSION: "4.11" 
EOF

tkn pipeline start -n edgecluster-deployer -p edgeclusters-config="$(cat edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub
