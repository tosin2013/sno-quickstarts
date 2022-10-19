#!/bin/bash
oc create namespace openshift-gitops
oc create -f init/
