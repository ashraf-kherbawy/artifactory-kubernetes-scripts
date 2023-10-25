#!/bin/bash

read -p "Enter the namespace you want the JFrog Platform chart to be installed in (If it doesn't exist, it will be created): " NAMESPACE 
echo
read -p "If you want to use your own values.yaml, enter the full path (If you want to use a simple deployment with minimal configurations installing only Artifactory and Xray, skip this): " VALUES_YAML
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

validate_procces() {

    if [ $? -eq 0 ]; then
        echo "$1"
        echo
    else
        echo "$2.."
        if [ "$3" -eq 0 ]; then
            exit 1
        fi
    fi

}

if [[ $VALUES_YAML == *.yaml ]];then

  echo "Installing the JFrog Platform chart.."

  helm upgrade --install jfrog-platform jfrog/jfrog-platform -n $NAMESPACE -f $VALUES_YAML ${CHART_VERSION:+--version "$CHART_VERSION"} 
  validate_procces "JFrog platform chart deployed successfully. Since non-Artifactory products will use the internal Artifactory URL, no need to configure those" "Failed to deploy JFrog Platform chart.." 1

elif [ -z $VALUES_YAML ];then 

  echo -e "Values.yaml file was not provided. Deploying JFrog platform chart with minimal settings.."
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
  
  cat <<EOF > jfrog-platform-values.yaml
  global:
    joinKey: $MASTER_KEY
    masterKey: $JOIN_KEY
  artifactory:
    enabled: true
    mc:
      enabled: true
  xray:
    enabled: true
  rabbitmq:
    enabled: true
  distribution:
    enabled: false
  insight:
    enabled: false
  pipelines:
    enabled: false
  redis:
    enabled: false
  pdnServer:
    enabled: false
EOF
  
  echo "Created your values.yaml. Check your local directory for: jfrog-platform-values.yaml"
  echo
  echo "Installing chart.."
  echo

  helm upgrade --install jfrog-platform jfrog/jfrog-platform -n $NAMESPACE \
  -f jfrog-platform-values.yaml \
  ${CHART_VERSION:+--version "$CHART_VERSION"} 

  validate_procces "JFrog platform chart deployed successfully. Since non-Artifactory products will use the internal Artifactory URL, no need to configure those" "Failed to deploy JFrog Platform chart.." 1

else

  echo -e "Provided Values.yaml is not valid. Make sure it's a valid yaml file. Exiting.."
  exit 1

fi