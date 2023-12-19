 # AWS Load Balancer Operator On ROSA
 
## Overview

### Configure the Operator

**Deploy Operator**
```
kustomize build gitops/cluster-config/aws-load-balancer-operator-on-rosa/operator/overlays  
```

**Using oc apply**
```
oc apply -k gitops/cluster-config/aws-load-balancer-operator-on-rosa/operator/overlays 
```

**Using oc apply**
```
oc apply -k https://github.com/tosin2013/sno-quickstarts/tree/main/gitops/cluster-config/aws-load-balancer-operator-on-rosa/operator/overlays
```

### Deploy a Load Balancer Instance

**Kustomize example**
```
kustomize build gitops/cluster-config/aws-load-balancer-operator-on-rosa/instance/overlay
```

**Using oc apply**
```
oc apply -k gitops/cluster-config/aws-load-balancer-operator-on-rosa/instance/overlay
```

## References
 * https://cloud.redhat.com/experts/rosa/aws-load-balancer-operator/
