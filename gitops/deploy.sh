#!/bin/bash
oc create namespace openshift-gitops
oc create -k gitops/cluster-config/openshift-gitops
sleep 30s
oc apply -k gitops/cluster-config/openshift-gitops
