# HostPath Provisioner

## A Second har drive is required for this to work.
>for libvirt machines it will use /dev/vdb by default. Change the vdb-machine-config.yaml kustomization.yaml to match your disk and update kustomization.yaml.


## Example Output 
```
 kustomize build gitops/cluster-config/hostpath-provisioner
```