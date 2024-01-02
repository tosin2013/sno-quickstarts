# AMQ Streams Operator

Installs the AMQ Streams operator into all namespaces.

Current channel overlays include:
* [amq-streams-1.x](overlays/1.x)
* [amq-streams-1.8.x](overlays/1.8.x)
* [amq-streams-2.x](overlays/2.x)
* [amq-streams-2.0.x](overlays/2.x)
* [amq-streams-2.1.x](overlays/2.x)
* [stable](overlays/stable)

## Usage

If you have cloned the `gitops-catalog` repository, you can install the AMQ Streams operator based on the overlay of your choice by running from the root `gitops-catalog` directory

```
oc apply -k amq-streams-operator/operator/overlays/<channel>
```

Or, without cloning:

```
oc apply -k https://github.com/tosin2013/gitops/cluster-config/amq-streams-operator/operator/overlays/<channel>
```

As part of a different overlay in your own GitOps repo:

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - github.com/tosin2013/gitops/cluster-config/amq-streams-operator/operator/overlays/<channel>?ref=main
```

Testing kafka clsuter instance:
```
kustomize build gitops/cluster-config/amq-streams-operator/instance/overlays 
```

## For Developers

**Deploy AMQ Operator**
```
oc login --token=sha256~YOURTOKEN --server=https://api.ocp4.exampl.com:6443
oc new-project my-project 
oc apply -k  https://github.com/tosin2013/sno-quickstarts/gitops/cluster-config/amq-streams-operator/operator/overlays/stable
```

**Deploy kafka instance**

*Option 1:*
```
git clone https://github.com/tosin2013/sno-quickstarts.git
cd sno-quickstarts
kustomize build gitops/cluster-config/amq-streams-operator/instance/overlays
# Update the kafka instance with the namespace and name 
vim gitops/cluster-config/amq-streams-operator/instance/overlays/kustomization.yaml
  - target:
      kind: Kafka
      name: kafka-cluster
    patch: |-
      - op: replace
        path: /metadata/namespace
        value: my-new-project
      - op: replace
        path: /metadata/name
        value: kafka-new-cluster
  - target:
      kind: Namespace
      name: my-project
    patch: |-
      - op: replace
        path: /metadata/name
        value: my-new-project

kustomize build gitops/cluster-config/amq-streams-operator/instance/overlays | oc apply -f -
or
oc create -k gitops/cluster-config/amq-streams-operator/instance/overlays
```

*Option 2: Deploy with no changes*
```
oc create -k https://github.com/tosin2013/sno-quickstarts/gitops/cluster-config/amq-streams-operator/instance/overlays
```