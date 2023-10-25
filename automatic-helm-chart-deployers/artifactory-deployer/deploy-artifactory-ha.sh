#!/bin/bash

read -p "Enter the namespace you want Artifactory to be installed in (If it doesn't exist, it will be created): " NAMESPACE 
echo
read -p "If you want to use your own values.yaml, enter the full path (If you want to use a simple deployment with minimal configurations, skip this): " VALUES_YAML
echo
read -p "Enter the chart's version that you want to deploy, leave empty for latest (Will work with both cases): " CHART_VERSION
echo

# Check if Namespace exists. If it doesn't, create it.
NAMESPACE_EXIST=$(kubectl get namespace | grep $NAMESPACE | sed 's/ //g')

if [ -z $NAMESPACE_EXIST ];then
    echo -e "Provided namespace doesn't exist. Creating..."
    kubectl create namespace $NAMESPACE
    echo
fi

if [[ $VALUES_YAML == *.yaml ]];then

  helm upgrade --install artifactory -name jfrog/artifactory-ha -n $NAMESPACE -f $VALUES_YAML ${CHART_VERSION:+--version "$CHART_VERSION"} >/dev/null 2>&1

  echo "Artifactory chart deployed successfully. If you want other JFrog products to connect to it, use the joinkey and the Artifacory Service's local DNS as jfrog url:"
  echo 
  echo "jfrogUrl = http://artifactory.$NAMESPACE.svc.cluster.local:8082"

elif [ -z $VALUES_YAML ];then 

  echo -e "Values.yaml file was not provided. Deploying Artifactory with minimal settings.."
  echo

  echo -e "Creating Masterkey and Joinkey.."
  echo 

  export MASTER_KEY=$(openssl rand -hex 32)
  export JOIN_KEY=$(openssl rand -hex 32)

  echo -e "Master key = $MASTER_KEY."
  echo -e "Join key = $JOIN_KEY"
  echo

  echo "Creating your minimal values.yaml.."
  echo
  
  cat <<EOF > artifactory-values.yaml
  artifactory:
    primary:
      replicaCount: 1
    masterKey: $MASTER_KEY
    joinKey: $JOIN_KEY
  postgresql:
    postgresqlUsername: "artifactory"
    postgresqlPassword: "password"
EOF
  
  echo "Created your values.yaml. Check your local directory for: artifactory-values.yaml"
  echo
  echo "Installing chart.."
  echo

  helm upgrade --install artifactory jfrog/artifactory-ha -n $NAMESPACE \
  --set artifactory.primary.replicaCount=1  \
  --set artifactory.joinKey=$JOIN_KEY  \
  --set artifactory.masterKey=$MASTER_KEY \
  --set postgresql.postgresqlUsername="artifactory" \
  --set postgresql.postgresqlPassword="password" \
  ${CHART_VERSION:+--version "$CHART_VERSION"} >/dev/null 2>&1

  echo "Artifactory chart deployed successfully. If you want other JFrog products to connect to it, use the joinkey and the Artifacory Service's local DNS as jfrog url:"
  echo
  echo "Join key = $JOIN_KEY"
  echo "jfrogUrl = http://artifactory.$NAMESPACE.svc.cluster.local:8082"

else

  echo -e "Provided Values.yaml is not valid. Make sure it's a valid yaml file. Exiting.."
  exit 1

fi