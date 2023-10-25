# This is a simple script which deploys PostgreSQL using the official bitnami charts.
# Requirements: Helm, Connection to a Kubernetes cluster, with an authenticated account that can use kubectl.
# -----------------------------
#!/bin/bash

echo "Enter namespace to deploy Postgres in (If provided namespace doesn't exist, it will be created):"
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
cat <<EOF > psql-values.yaml
auth:
  enablePostgresUser: true
  postgresPassword: "password"
  username: "artifactory"
  password: "password"
  database: "artifactory"
global:
  storageClass: $STORAGE_CLASS
primary:
  persistence:
    enabled: true
volumePermissions:
  enabled: true
EOF

echo "Deploying PostgreSQL chart.."
echo
# Deploy PostgreSQL.
if helm upgrade --install postgresql bitnami/postgresql -n $NAMESPACE -f psql-values.yaml >/dev/null 2>&1; then
    echo "PostgreSQL chart deployed successfully. Use it's Service ClusterIP or Service local DNS as the database url for Artifactory:"
    echo

    echo "Cluster IP to use as database url = $(kubectl get service postgresql -n $NAMESPACE -o jsonpath='{.spec.clusterIP}'):5432"
    echo 

    echo "Local service DNS = postgresql.$NAMESPACE.svc.cluster.local:5432"

    echo "Database = artifactory"
    echo "Username = artifactory"
    echo "Password = password"
else 
    echo "Failed to install chart"
fi


