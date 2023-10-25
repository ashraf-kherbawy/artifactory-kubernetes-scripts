# Automatic Helm Chart Deployers

This repository includes a number of bash scripts that will automatically deploy JFrog and Bitnami related Helm charts, to save time when trying to 
spin up quick Helm deployments for lab environments. Each script works in a slightly different way, to comply with it's own values.

## Current tree of deployers

automatic-helm-chart-deployers
├── artifactory-deployer
│   ├── deploy-artifactory-ha.sh
│   └── deploy-artifactory.sh
├── jfrog-platform-deployer
│   └── deploy-jfrog-platform.sh
├── mysql-deployer
│   └── mysql-deployer.sh
└── postgresql-deployer
    └── postgresql-deployer.sh
