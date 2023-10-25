# MySQL deployer

This script will deploy MySQL using the official Bitnami chart, with a database ready for Artifactory.

This is meant to have a fast working MySQL for testing purposes with Artifactory, and is not suitable for production level systems.

## How it works

The script will take in one prompt for the namespace, and will create the namespace if it doesn't exist. It will add the bitnami repo, and install the MySQL chart, using simple values that it creates and saves locally for you to edit if needed:
```
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
```

The StorageClass variable will depend wether you are using EKS or not. If you use EKS, it will use gp2, which is the default StorageClass in EKS. If you are not 
using EKS, it will use standard, which is the default StorageClass for most cloud providers (GKE, AKS. etc..). Obviously if you are using a provider which isn't using EKS
or a Kubernetes engine that doesn't have a StorageClass named "standard", then this won't work.

## Usage with Artifactory

Once you deploy the chart, you can pass in Artifactory's values.yaml file, the database credentials like the following:

```
artifactory:
  replicaCount: 1

database:
  type: mysql
  driver: org.mysql.Driver
  url: jdbc:mysql://$CLUSTER-IP:5432/artifactory?characterEncoding=UTF-8&elideSetAutoCommits=true&useSSL=false ## OR use mysql.$NAMESPACE.svc.cluster.local instead of ClusterIP
  username: artifactory
  password: password
```