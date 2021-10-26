#!/usr/bin/env bash

ENV="credentials"

function prop {
    grep "${1}" ../../${ENV}.properties | grep -vE "^#" | cut -d'=' -f2 | sed 's/"//g'
}

if [[ -f "../../${ENV}.properties" ]]; then
    # Load the credentials
    export TF_VAR_ibmcloud_api_key=$(prop 'ibmcloud.api.key')
    export TF_VAR_namespace=$(prop 'openshift.namespace')
    export TF_VAR_login_token=$(prop 'openshift.token')
else
    helpFunction "The ${ENV}.properties file is not found."
fi