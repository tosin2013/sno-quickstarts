# OpenShift Data Foundation

Installs a basic Storage System using the OpenShift Data Foundation Operator.

## Prerequisites

OpenShift Data Foundation requires a minimum three worker nodes to install and configure a ceph cluster using OpenShift Data Foundation.

First, install the [OpenShift Data Foundation Operator](../operator) in your cluster.

Do not use the `base` directory directly, as you will need to patch the `channel` based on the version of OpenShift you are using, or the version of the operator you want to use.

## Overlays

The options for this operator are the following *overlays*:
* [aws](overlays/aws)
* [bare-metal](overlays/bare-metal)
* [vsphere](overlays/vsphere)
* 
### AWS

[aws](overlays/aws) installs a basic StorageSystem.  The StorageSystem will configure the OpenShift Container Storage Operator and also install a StorageCluster and OCSInitilization object to configure the storage cluster.  The StorageCluster is configured to work with gp2 storage on an AWS cluster.

### Baremetal

[bare-metal](overlays/bare-metal) installs a basic StorageSystem.  The StorageSystem will configure the OpenShift Container Storage Operator and also install a StorageCluster and OCSInitilization object to configure the storage cluster.  The StorageCluster is configured to work with local storage on an Baremetal cluster.

### vSphere

[vsphere](overlays/vsphere) installs a basic StorageSystem.  The StorageSystem will configure the OpenShift Container Storage Operator and also install a StorageCluster and OCSInitilization object to configure the storage cluster.  The StorageCluster is configured to work with thin storage on a vSphere cluster and enables flexible scaling to distribute devices evenly across all nodes, regardless of distribution in zones or racks.   

## Usage

If you have cloned the `gitops-catalog` repository, you can install the Storage System by running from the root `gitops-catalog` directory

```
oc apply -k openshift-data-foundation-operator/instance/overlays/default
```

Or, without cloning:

```
oc apply -k https://github.com/tosin2013/gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/default
```

As part of a different overlay in your own GitOps repo:

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - github.com/tosin2013/gitops/cluster-config/openshift-data-foundation-operator/instance/overlays/default?ref=main
```