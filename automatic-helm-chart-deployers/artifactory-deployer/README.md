# Artifactory Deployer

This directory contains two deployers:

    1. Artifactory deployer, which deploys the regular Artifactory chart.
    2. Artifactory-ha deployer, which deploys the Artifactory-ha chart.

## Usage

Both scripts will prompt you 3 different inputs: 

    1. Namespace (Will be created if the given namespace doesn't exist)
    2. Optional values.yaml (Can be skipped to deploy a quick minimal deployment that can be used for testing)
    3. Optional chart version (Can be skipped to use latest instead)

If a values.yaml is passed, the script will run a regular Helm upgrade --install command. If no values.yaml is passed, the script will instead create a minimal
values.yaml, a join key and a master key, place the values.yaml in your local directory, and install the minimal values.yaml