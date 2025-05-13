#!/bin/bash -e

########################################
# Functions
########################################

# Function to generate or load the values for environment variables
# and store them in a .env file
generateVars(){

  K8SUSER=$RANDOM
  K8SPASSWORD=$RANDOM
  echo "This is your user/password for the webshell. Please keep it safe."
  echo "K8SUSER: $K8SUSER"
  echo "K8SPASSWORD: $K8SPASSWORD"
  K8SUSER_BASE64=$(echo -n $K8SUSER | base64)
  K8SPASSWORD_BASE64=$(echo -n $K8SPASSWORD | base64)

  # Check if the user provided values for the environment variables
  # If not, use the defaults
  export RESOURCE_GROUP="${RESOURCE_GROUP:-ctf-rg}"
  export AKS_NAME="${AKS_NAME:-ctf-aks}"
  export ACR_NAME="${ACR_NAME:-acr${RANDOM}}"

  # Create a .env file with the generated values
  # This can be used to reload the values if the script is run again
  cat <<EOF >.env
  K8SUSER=$K8SUSER
  K8SPASSWORD=$K8SPASSWORD
  K8SUSER_BASE64=$K8SUSER_BASE64
  K8SPASSWORD_BASE64=$K8SPASSWORD_BASE64
  RESOURCE_GROUP=$RESOURCE_GROUP
  AKS_NAME=$AKS_NAME
  ACR_NAME=$ACR_NAME 
EOF
}

# Function to load the values from the .env file
loadExistingVars(){
  source ./.env
  echo "K8SUSER: $K8SUSER"
  echo "K8SPASSWORD: $K8SPASSWORD"
  echo "K8SUSER_BASE64: $K8SUSER_BASE64"
  echo "K8SPASSWORD_BASE64: $K8SPASSWORD_BASE64"
  echo "RESOURCE_GROUP: $RESOURCE_GROUP"
  echo "AKS_NAME: $AKS_NAME"
  echo "ACR_NAME: $ACR_NAME"
}

# Function to deploy the Kubernetes resources
deployKubernetesResources(){
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: dev
type: Opaque
data:
  username: $K8SUSER_BASE64
  password: $K8SPASSWORD_BASE64
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: prod
type: Opaque
data:
  username: $K8SUSER_BASE64
  password: $K8SPASSWORD_BASE64
EOF

# Create the registry credentials
kubectl create secret docker-registry acr-secret \
  --namespace dev \
  --docker-server $ACR_NAME.azurecr.io \
  --docker-username $ACR_USERNAME \
  --docker-password $ACR_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# build the app image
az acr build --no-logs -r $ACR_NAME -t insecure-app:latest -t insecure-app:1.0 ./insecure-app/

cat <<EOF >>./manifests/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- omnibus.yml
images:
- name: aks-ctf/insecure-app
  newName: ${ACR_NAME}.azurecr.io/insecure-app
EOF

kubectl apply -k ./manifests
}

getClusterAndACRCreds(){
# Get the ACR Credentials
ACR_USERNAME=$(az acr credential show -n $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show -n $ACR_NAME --query 'passwords[0].value' -o tsv)

# Fetch a valid kubeconfig
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --admin --overwrite-existing 
# Grab a copy for scenario 1
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --admin --overwrite-existing --file ./scenario_1/kubeconfig

}
########################################
# End of Functions
########################################

########################################
# Main Script
########################################

# Generate or load existing values for the environment variables
if ! [ -f ./.env ]; then
echo "Loading and generating values for the environment variables..."
generateVars
else
# Load the values from the existing .env file
echo "File .env exists. Loading values from .env file..."
loadExistingVars
fi

# Get the cluster and ACR credentials
echo "Getting the cluster and ACR credentials..."
getClusterAndACRCreds

# Deploy the Kubernetes resources
echo "Deploying Kubernetes resources..."
deployKubernetesResources


########################################
# End Main Script
########################################
