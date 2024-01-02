# Crunchy Postgres Certified Operator

Installs the Crunchy Postgres Certified operator into all namespaces.

Current channel overlays include:
* v5

## Usage

If you have cloned the `gitops-catalog` repository, you can install the Crunchy Postgres Certified operator based on the overlay of your choice by running from the root `gitops-catalog` directory

```
oc apply -k crunchy-postgres/operator/overlays/<channel>
```

Or, without cloning:

```
oc apply -k https://github.com/tosin2013/gitops/cluster-config/crunchy-postgres/operator/overlays/<channel>
```

As part of a different overlay in your own GitOps repo:

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - github.com/tosin2013/gitops/cluster-config/crunchy-postgres/operator/overlays/<channel>?ref=main
```


## Developer Instructions

```
oc apply -k https://github.com/tosin2013/sno-quickstarts/gitops/cluster-config/crunchy-postgres/operator/overlays/v5
```

**Deploy Postgres instance**
*Option 1:*
```
git clone https://github.com/tosin2013/sno-quickstarts.git
cd sno-quickstarts
kustomize build gitops/cluster-config/crunchy-postgres/instance/overlays
# Update the kafka instance with the namespace and name 
vim gitops/cluster-config/crunchy-postgres/instance/instance/kustomization.yaml
patches:
  - target:
      kind: PostgresCluster
      name: example
    patch: |-
      - op: replace
        path: /metadata/namespace
        value: database-project
      - op: replace
        path: /metadata/name
        value: example-database
      - op: replace
        path: /spec/users/0/databases/0
        value: exampledb
      - op: replace
        path: /spec/users/0/name
        value: exampleuser
  - target:
      kind: Namespace
      name: my-project
    patch: |-
      - op: replace
        path: /metadata/name
        value: database-project

kustomize build gitops/cluster-config/crunchy-postgres/instance/overlays | oc apply -f -
or
oc create -k gitops/cluster-config/crunchy-postgres/instance/overlays
```

*Option 2: Deploy with no changes*
```
oc create -k https://github.com/tosin2013/sno-quickstarts/gitops/cluster-config/crunchy-postgres/instance/overlays
```

## Links: 
* https://github.com/CrunchyData/postgres-operator-examples/tree/main
