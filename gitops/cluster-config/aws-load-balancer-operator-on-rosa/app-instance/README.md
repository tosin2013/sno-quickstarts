# Deploy Echo server

Deploy this server to test the load balancer.

```
$ oc apply -k gitops/cluster-config/aws-load-balancer-operator-on-rosa/app-instance
```