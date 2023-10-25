# This is a simple script which deploys MySQL using the official bitnami charts.
# Requirements: Helm, Connection to a Kubernetes cluster, with an authenticated account that can use kubectl.
# Created by Ashraf Kherbawy.
# -----------------------------
#!/bin/bash

# Constant color vars
ORANGE='\033[0;33m'
NC='\033[0m' # No color
CYAN='\033[0;36m'

echo "Enter namespace. (If provided namespace doesn't exist, it will be created):"
read NAMESPACE
echo
# Check if Namespace exists. If it doesn't, create it.
NAMESPACE_CHECK=$(kubectl get namespace | grep $NAMESPACE | sed 's/ //g')

if [ -z $NAMESPACE_CHECK ]
  then
    echo "${ORANGE}Provided namespace doesn't exist. Creating...${NC}"
    kubectl create namespace $NAMESPACE
    echo
fi

echo "Adding Bitnami repository to Helm.."
echo
# Add Helm repository by Bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
# Update Helm index charts
helm repo update bitnami
echo

echo "Creating PV and PVC.."
# Create PV, and apply it to cluster.
cat <<EOF > mysql-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
  labels:
    type: local
spec:
  storageClassName: standard
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/var/lib/data"
EOF

kubectl apply -f mysql-pv.yaml -n $NAMESPACE
echo

echo "Saving values.yaml to local machine.."
echo
# Create a values.yaml file which contains minimalistic settings.
cat <<EOF > mysql-values.yaml
primary:
  persistence:
    storageClass: standard
    accessModes:
      - ReadWriteMany
    size: 50Gi
auth:
  rootPassword: password
  database: artifactory
  username: artifactory
  password: password
EOF

echo "Deploying MySQL chart.."
echo
# Deploy MySQL.
helm upgrade --install mysql bitnami/mysql -n $NAMESPACE -f mysql-values.yaml 
echo

echo "MySQL chart deployed successfully. Use it's Service ClusterIP or Service local DNS as the database url:"
echo

echo "Cluster IP to use as database url = $(kubectl get service mysql -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')"
echo 

echo "Database = artifactory"
echo "Username = artifactory"
echo "Password = password"

---
# This is a simple script which deploys PostgreSQL using the official bitnami charts.
# Requirements: Helm, Connection to a Kubernetes cluster, with an authenticated account that can use kubectl.
# -----------------------------
#!/bin/bash

echo "Enter namespace to deploy MySQL in (If provided namespace doesn't exist, it will be created):"
read NAMESPACE

# Use kubectl get namespace to check if the namespace does not exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Namespace $NAMESPACE does not exist. Creating.."
    kubectl create namespace $NAMESPACE
fi


# Check if using EKS cluster to use GP2 for standard. Otherwise use standard.
CURRENT_CONTEXT=$(kubectl config current-context)
STORAGE_CLASS=""

if [[ $CURRENT_CONTEXT == *"eks"* ]]; then
    echo "The current cluster is running on EKS. Using 'gp2' as storageClass.."
    echo
    STORAGE_CLASS="gp2"
else 
    echo "The current cluster is not running on EKS. Using 'standard' as a storageClass.."
    echo
    STORAGE_CLASS="standard"
fi

echo "Adding Bitnami repository to Helm.."
echo

# Add Helm repository by Bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
# Update Helm index charts
helm repo update bitnami
echo

echo "Saving values.yaml to local machine.."
echo
# Create a values.yaml file which contains minimalistic settings.
cat <<EOF > mysql-values.yaml
primary:
  persistence:
    storageClass: $STORAGE_CLASS
    accessModes:
      - ReadWriteMany
    size: 50Gi
auth:
  rootPassword: password
  database: artifactory
  username: artifactory
  password: password
EOF

echo "Deploying MySQL chart.."
echo
# Deploy MySQL.
if helm upgrade --install mysql bitnami/mysql -n $NAMESPACE -f mysql-values.yaml  >/dev/null 2>&1; then

    echo
    echo "MySQL chart deployed successfully. Use it's Service ClusterIP or Service local DNS as the database url:"
    echo

    echo "Cluster IP to use as database url = $(kubectl get service mysql -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')"
    echo 

    echo "Local service DNS = mysql.$NAMESPACE.svc.cluster.local:3306"

    echo "Database = artifactory"
    echo "Username = artifactory"
    echo "Password = password"
else 
    echo "Failed to install chart.."
fi


