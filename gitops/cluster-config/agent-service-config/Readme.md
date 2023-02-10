# Notes
https://github.com/adetalhouet/ocp-ztp
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/

https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.6/html/multicluster_engine/multicluster_engine_overview#enable-cim


Connected
```
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true }}'
oc apply -k gitops/cluster-config/agent-service-config/connected
```

Disconnected
```
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true }}'
oc apply -k gitops/cluster-config/agent-service-config/disconnected

oc get pod -n multicluster-engine -l app=assisted-service
```

```
git clone https://github.com/adetalhouet/ocp-ztp.git
cd ocp-ztp
export CLUSTER_NAME=sno-r620
export DOMAIN_NAME=lab.qubinode.io
sed -i "s/hub-adetalhouet.rhtelco.io/$CLUSTER_NAME.$DOMAIN_NAME/g" metal-provisioner/02-ironic.yaml
cat metal-provisioner/02-ironic.yaml
oc apply -k metal-provisioner
 ```