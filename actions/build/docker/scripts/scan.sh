#!/bin/bash
HARBOR_ENDPOINT="https://${IMAGE_REPOSITORY}/api/v2.0"
ARTIFACT_SCAN_ENDPOINT="https://${HARBOR_ENDPOINT}/api/v2.0/projects/${1}/repositories/${2}/artifacts/${3}/scan"
VAULT_TOKEN=$VAULT_TOKEN
VAULT_SERVER=$VAULT_SERVER
VAULT_PATH=$VAULT_SECRETS_CICD_PATH
PROJECT_NAME=$(echo $VAULT_SECRET_PATH | awk -F '/' '{print $1}')

#Pull creds from vault

USERNAME=$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_PATH}" | jq -r .data.KCR_USER)
PASSWORD=$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_PATH}" | jq -r .data.KCR_PASSWORD)


scan() {
    local RESPONSE=$(curl --write-out ${http_code} --silent --output /dev/null -s -u "$USERNAME:$PASSWORD" "$ARTIFACT_SCAN_ENDPOINT")
    echo $RESPONSE

    if [$RESPONSE -eq 201]; then
        echo "Scan successfully initiated"
    else
        echo "Failed to start scan" &> /dev/null
    fi
}

scan()