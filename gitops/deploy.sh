#!/bin/bash
oc create namespace openshift-gitops
oc create -k cluster-config/openshift-gitops
sleep 30s
oc apply -k cluster-config/openshift-gitops
