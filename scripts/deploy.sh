#!/bin/bash

DOMAIN="stktrur-200210-1-345785d9ad39a5ed2bf7de019084c0fb-0000.eu-de.containers.appdomain.cloud"
UNIQUE_STRING=$(head /dev/urandom | tr -dc a-za-z0-9 | head -c 4)

read -p "Enter Namespace name: " NAMESPACE_NAME
NAMESPACE_NAME="$NAMESPACE_NAME-$UNIQUE_STRING"

echo "Namespace: $NAMESPACE_NAME"

#Replace DOMAIN placeholder
find . -type f -name "*.yaml" -print0 | xargs -0 sed -i "s|DOMAIN|${DOMAIN}|g"
find . -type f -name "*.json" -print0 | xargs -0 sed -i "s|DOMAIN|${DOMAIN}|g"

#Replace NAMESPACE placeholder
find . -type f -name "*.yaml" -print0 | xargs -0 sed -i "s|NAMESPACE_NAME|${NAMESPACE_NAME}|g"
find . -type f -name "*.json" -print0 | xargs -0 sed -i "s|NAMESPACE_NAME|${NAMESPACE_NAME}|g"
sed -i "s|NAMESPACE_NAME|${NAMESPACE_NAME}|g" scripts/destroy.sh

#Replace KEYCLOAK_CONFIG
KEYCLOAK_CONFIG=`cat configs/keycloak.json | base64 -w 0`
sed -i "s|KEYCLOAK_CONFIG|${KEYCLOAK_CONFIG}|g" secrets/secret-keycloak-config.yaml

#Create namespace
oc create namespace $NAMESPACE_NAME
oc label namespace $NAMESPACE_NAME prometheus=stakater-workload-monitoring

#Fix permission issue on openshift
oc adm policy add-scc-to-user anyuid system:serviceaccount:$NAMESPACE_NAME:default

#Apply manifests
oc apply -f secrets/ --namespace=$NAMESPACE_NAME 2>/dev/null

n=0
until [ $n -ge 3 ]
do
   oc apply -R -f . --namespace=$NAMESPACE_NAME 2>/dev/null && break
   n=$[$n+1]
   echo "Retrying for $n/3 times..."
done

echo "Front-end URL: web-$NAMESPACE_NAME.$DOMAIN"
echo "Gateway URL: gateway-$NAMESPACE_NAME.$DOMAIN"
