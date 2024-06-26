#!/bin/bash

set -xe

ENVIRONMENT=$ENVIRONMENT
PROJECT_NAME=$PROJECT_NAME
VAULT_TOKEN=$VAULT_TOKEN
VAULT_SERVER=$VAULT_SERVER
VAULT_SECRET_PATH=$VAULT_SECRET_PATH
VAULT_SECRET_COMMON_PATH=$VAULT_SECRET_COMMON_PATH
VAULT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Vault-Token: ${VAULT_TOKEN}" --insecure https://${VAULT_SERVER}/v1/sys/ha-status)
GITLAB_TOKEN=$GITLAB_TOKEN
GITLAB_SERVER=$GITLAB_SERVER
GITLAB_PROJECT_NUMBER=$GITLAB_PROJECT_NUMBER
GITLAB_TOKEN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${GITLAB_SERVER}/api/v4/user")
LOCAL_SETTINGS=$LOCAL_SETTINGS
LOCAL_SETTINGS_NAME=$LOCAL_SETTINGS_NAME
NAMESPACE=$NAMESPACE
KCR_USER=$KCR_USER
KCR_PASSWORD=$KCR_PASSWORD
IMAGE_REPOSITORY=$IMAGE_REPOSITORY
ECR_REPOSITORY=$ECR_REPOSITORY
AUTOSCALER=$AUTOSCALER


export KUBECONFIG=kubeconfig.yaml

function configmap() {
  LOCAL_SETTINGS_NAME=$1
  if [ -f ${LOCAL_SETTINGS_NAME} ]; then
    echo "${LOCAL_SETTINGS_NAME} exists.. Continuing creating configmap"
    if kubectl get configmaps app-local-settings --namespace=${NAMESPACE} &> /dev/null; then
      kubectl delete configmap app-local-settings --namespace=${NAMESPACE}
      kubectl create configmap app-local-settings --from-file=${LOCAL_SETTINGS_NAME} --namespace=${NAMESPACE}
    else
      kubectl create configmap app-local-settings --from-file=${LOCAL_SETTINGS_NAME} --namespace=${NAMESPACE}
    fi
  else
    echo "File ${LOCAL_SETTINGS_NAME} does not exist."
    exit 1
  fi
}

if [ "${ECR_REPOSITORY}" == "python-django" ]; then
    if [ "${LOCAL_SETTINGS}" == "true" ]; then
      if [ "${GITLAB_TOKEN_STATUS}" == "200" ]; then
        echo "Downloading Latest Settings file..."
        curl -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${GITLAB_SERVER}/api/v4/projects/${GITLAB_PROJECT_NUMBER}/repository/files/${ENVIRONMENT}%2F${LOCAL_SETTINGS_NAME}/raw?ref=main" -o ${LOCAL_SETTINGS_NAME}
        echo "Creating settings configmap..."
        configmap ${LOCAL_SETTINGS_NAME}
      else
        echo "Issue with Gitlab Token"
        exit 1
      fi
    elif [ "${LOCAL_SETTINGS}" == "false" ]; then
      echo "Dummy Settings" > settings.txt
      echo "Creating dummy settings configmap"
      configmap settings.txt
    fi
else  
  echo "Skipping ConfigMap"
fi

if [ "${ECR_REPOSITORY}" == "python-django" ]; then
  if [ "${VAULT_STATUS}" == "200" ]; then
    echo "Extracting variables from Vault..."
    curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_SECRET_PATH}" | jq -r .data > .env.json
    curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_SECRET_COMMON_PATH}" | jq -r .data > .common.env.json
    cat .env.json | jq -r 'to_entries[] | "\(.key)=\(.value)"' | base64 > secrets
    cat .common.env.json | jq -r 'to_entries[] | "\(.key)=\(.value)"' | base64 >> secrets
    if [ -f "secrets" ]; then
      if kubectl get secret app-secret --namespace=${NAMESPACE} &> /dev/null; then
        echo "Creating secrets from variables..."
        kubectl delete secret app-secret --namespace=${NAMESPACE}
        kubectl create secret generic app-secret --from-file=secrets --namespace=${NAMESPACE}
      else
        echo "Creating secrets from variables..."
        kubectl create secret generic app-secret --from-file=secrets --namespace=${NAMESPACE}
      fi
    else
      echo "Secrets file does not exist."
      exit 1
    fi
  else
    echo "Vault Status is ${VAULT_STATUS}"
    exit 1
  fi
else
   echo "Skipping Secrets"
fi

if [ "${AUTOSCALER}" == "true" ]; then 
  if kubectl get secret rabbitmq-secret --namespace=${NAMESPACE} &> /dev/null; then
    echo "Creating rabbitmq-secret from variables..."
    kubectl delete secret rabbitmq-secret --namespace=${NAMESPACE}
    kubectl create secret generic --namespace=${NAMESPACE} rabbitmq-secret --from-literal=host=amqp://${SETTINGS_RABBITMQ_USER}:${SETTINGS_RABBITMQ_PASSWORD}@${SETTINGS_RABBITMQ_HOST1}:5672/${SETTINGS_RABBITMQ_USER}
  else
    echo "Creating rabbitmq-secret from variables..."
    kubectl create secret generic --namespace=${NAMESPACE} rabbitmq-secret --from-literal=host=amqp://${SETTINGS_RABBITMQ_USER}:${SETTINGS_RABBITMQ_PASSWORD}@${SETTINGS_RABBITMQ_HOST1}:5672/${SETTINGS_RABBITMQ_USER} 
  fi
fi
