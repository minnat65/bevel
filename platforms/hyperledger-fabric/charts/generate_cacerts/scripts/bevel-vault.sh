#!/bin/bash
# This function validates hashicorp vault responses 
function validateVaultResponseHashicorp {
    if echo ${2} | grep "errors" || [[ "${2}" = "" ]]; then
        echo "ERROR: unable to retrieve ${1}: ${2}"
        exit 1
    fi
    if  [[ "$3" = "LOOKUPSECRETRESPONSE" ]]
    then
        http_code=$(curl -fsS -o /dev/null -w "%{http_code}" \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        ${VAULT_ADDR}/v1/${1})
        curl_response=$?
        if test "$http_code" != "200" ; then
            echo "Http response code from Vault - $http_code and curl_response - $curl_response"
            if test "$curl_response" != "0"; then
                echo "Error: curl command failed with error code - $curl_response"
                exit 1
            fi
        fi
    fi
}

## Hashicorp vault related function ##

function initHashicorpVaultToken {
    VAULT_TOKEN=$(curl -sS --request POST ${VAULT_ADDR}/v1/auth/${KUBERNETES_AUTH_PATH}/login -H "Content-Type: application/json" -d \
                '{"role":"'"${VAULT_APP_ROLE}"'","jwt":"'"${KUBE_SA_TOKEN}"'"}' | jq -r 'if .errors then . else .auth.client_token end')
}

#Arg1: Vault token; Arg2: Secret Path
function readHashicorpVaultSecret {
    VAULT_SECRET=$(curl --header "X-Vault-Token: ${1}" ${VAULT_ADDR}/v1/${2} | jq -r 'if .errors then . else . end')
}

## Hashicorp vault functions end ##


## Azure vault related function ##
function initAzureVaultToken {
    VAULT_TOKEN=$(curl --location --request POST https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token \
                                --form 'grant_type="client_credentials"' \
                                --form 'client_id="'${CLIENT_ID}'"' \
                                --form 'client_secret="'${CLIENT_SECRET}'"' \
                                --form 'scope="https://vault.azure.net/.default"' | jq '.access_token' | sed -e 's/^"//' -e 's/"$//')
}

#Arg1: Secret keyname
function readAzureVaultSecret {
    VAULT_SECRET=$(curl --location --request GET ${VAULT_ADDR}/secrets/${1}?api-version=7.3 \
                                    --header 'Authorization: Bearer '${VAULT_TOKEN} | jq '.value' | sed -e 's/^"//' -e 's/"$//')
}

#Arg1: Secret keyname
#Arg2: Secret value
function writeAzureVaultSecret {
    JSON_PAYLOAD=$2
    VAULT_RESPONSE=$(curl --location --request PUT ${VAULT_ADDR}/secrets/${1}?api-version=7.3 \
                                    --header 'Authorization: Bearer '${VAULT_TOKEN} --header 'Content-Type: application/json' \
                                    --data-raw '{"value": "'"$JSON_PAYLOAD"'"}' )
    echo $VAULT_RESPONSE
}

## Azure vault function ends ##
vaultBevelFunc() {
    if [[ $VAULT_TYPE = "hashicorp" ]]; then
        if [[ $1 = "init" ]] 
        then
            initHashicorpVaultToken
            echo $VAULT_TOKEN 
        fi
        if [[ $1 = "read" ]] 
        then
            readHashicorpVaultSecret
            echo $VAULT_SECRET
        fi
        if [[ $1 = "write" ]] 
        then
            writeHashicorpSecret
            echo $RESULT
        fi
    fi

    if [[ $VAULT_TYPE = "azure" ]] 
    then
        if [[ $1 = "init" ]] 
        then
            initAzureVaultToken
            echo $VAULT_TOKEN
        fi
        if [[ $1 = "read" ]] 
        then
            if [[ $2 = "" ]]
            then
                exit 1
            else
                readAzureVaultSecret $(echo $2 | sed -e 's!/!-!g')
                echo $VAULT_SECRET
            fi
        fi
        if [[ $1 = "write" ]] 
        then
            echo $3
            writeAzureVaultSecret $(echo $2 | sed -e 's!/!-!g') "$3"
            echo $RESULT
        fi
    fi
}