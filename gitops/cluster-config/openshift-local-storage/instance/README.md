# OpenShift Local Storage 

Installs a basic using the  OpenShift Local Storage  Operator.

## Prerequisites

First, install the [ OpenShift Local Storage Operator](../operator) in your cluster.

Do not use the `base` directory directly, as you will need to patch the `channel` based on the version of OpenShift you are using, or the version of the operator you want to use.

## Overlays

The instaconfnce options for this operator currently offers the following *overlays*:
* [bare-metal](overlays/bare-metal)

### bare-metal

[bare-metal](overlays/bare-metal) installs a basic Local storage on baremetal.

## Usage

If you have cloned the `gitops-catalog` repository, you can install the Storage System by running from the root `gitops-catalog` directory

```
oc apply -k openshift-local-storage/instance/overlays/default
```

Or, without cloning:

```
oc apply -k https://github.com/redhat-cop/gitops-catalog/openshift-local-storage/instance/overlays/default
```

As part of a different overlay in your own GitOps repo:

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - github.com/redhat-cop/gitops-catalog/openshift-local-storage/instance/overlays/default?ref=main
```
