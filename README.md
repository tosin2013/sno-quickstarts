# sno-quickstarts

Argo CD applicatioins to configure a SNO openshift cluster. 

## Deployment Types: 
* SNO (Single Node Openshift) witn OpenShift Virtualization
  * RHACM (Red Hat Advanced Cluster Management)
  * chronyc (chrony client)
  * hostpath-provisioner (hostpath-provisioner)
  * mutli-cluster engine
  * Openshift gitops
  * Openshift pipelines
  * OpenShift Virtualization
* SNO (Single Node Openshift) for Standard Deployments

## Prerequisites
* OpenShift 4.11 Cluster installed via the Assisted Installer 
  * [Assisted Installer Scripts](https://github.com/tosin2013/openshift-4-deployment-notes/tree/master/assisted-installer)
  * [OpenShift Assisted Installer Service, Universal Deployer](https://github.com/tosin2013/ocp4-ai-svc-universal)


## Deploying the SNO Quickstart
**Fork reposity to your own repo**

**Login into the OpenShift Cluster as a cluster-admin user**
```bash
oc login -u kubeadmin -p <password> https://api.<cluster-name>.<domain>:6443
```

**run deploy.sh script**
```
cd gitops
./deploy.sh
```

**add registry to ArgoCD cluster**

### Configure Cluster
### Review Argo CD Applications before deployment 
**SNO (Single Node Openshift) witn OpenShift Virtualization**
> you will have to make changes to the repos in the yaml files you will also need to remove any files that are not needed for your deployment.
```
cd gitops/cluster-config/apps/sno-ocp-virt
```

**SNO (Single Node Openshift) for Standard Deployments**
> you will have to make changes to the repos in the yaml files you will also need to remove any files that are not needed for your deployment.
```
cd gitops/apps/standard-sno-deployment/
```

#### SNO (Single Node Openshift) witn OpenShift Virtualization
**Change Repo path**
```
vim gitops/apps/sn-ocp-virt/cluster-config.yaml
```
**Apply Configuration to clutser**
```
oc create -f gitops/apps/sn-ocp-virt/cluster-config.yaml
```
#### SNO (Single Node Openshift) for Standard Deployments
**Change Repo path**
```
vim gitops/apps/standard-sno-deployment/cluster-config.yaml
```
**Apply Configuration to clutser**
```
oc create -f gitops/apps/standard-sno-deployment/cluster-config.yaml
```



## Links:
* https://github.com/redhat-cop/gitops-catalog
* https://github.com/noseka1/rhacm-kustomization