#!/usr/bin/env bash

oc delete project ${TF_VAR_namespace}
rm -rf .tmp
rm -rf gitops
rm .kubeconfig
rm .terraform.lock.hcl
rm terraform.tfstate