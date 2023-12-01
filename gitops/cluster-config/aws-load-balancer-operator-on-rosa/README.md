 # AWS Load Balancer Operator On ROSA
 
### Overview

**Deploy Operator**
```
kustomize build gitops/cluster-config/aws-load-balancer-operator-on-rosa/operator/overlays  
```

**Using oc apply**
```
oc apply -k gitops/cluster-config/aws-load-balancer-operator-on-rosa/operator/overlays 
```


 * https://cloud.redhat.com/experts/rosa/aws-load-balancer-operator/