#!/bin/bash
set -xe

HARBOR_ENDPOINT="https://${IMAGE_REPOSITORY}/api/v2.0"
echo $IMAGE_REPOSITORY
VAULT_TOKEN=$VAULT_TOKEN
VAULT_SERVER=$VAULT_SERVER
VAULT_PATH=$VAULT_SECRETS_CICD_PATH
PROJECT_NAME=$(echo $VAULT_SECRET_PATH | awk -F '/' '{print $1}')
REPO_NAME=$(echo $1 | awk -F '/' '{print $(NF-1)}')
ARTIFACT_SCAN_ENDPOINT="${HARBOR_ENDPOINT}/projects/${PROJECT_NAME}/repositories/${REPO_NAME}/artifacts/${2}/scan"


#Pull creds from vault

USERNAME=$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_PATH}" | jq -r .data.KCR_USER)
PASSWORD=$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_PATH}" | jq -r .data.KCR_PASSWORD)


scan() {
    local RESPONSE=$(curl -w "%{http_code}" --silent --output /dev/null -s -u "$USERNAME:$PASSWORD" "$ARTIFACT_SCAN_ENDPOINT")
    echo $RESPONSE

    if [ "$RESPONSE" -eq 201 ]; then
        echo "Scan successfully initiated"
    else
        echo "Failed to start scan" &> /dev/null
    fi
}

scan
