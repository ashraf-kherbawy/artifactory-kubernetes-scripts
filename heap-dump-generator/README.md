# Artifactory Kubernetes Heapdump Generator

Both bash scripts were designed to generate a heapdump in an Artifactory container, running on Kubernetes. This was made in mind to save time and effort, to debug high memory issues.

## Usage

Artifactory HA heapdump generator:

This script will take 2 prompts, the release name, and the namespace. It will go over all of the pods, and collect a heapdump and histogram in each Artifactory container. This is useful
when you are encountering high memory usage on multiple pods.

Artifactory heapdump generator:

This script will take 2 prompts, the pod name, and the namespace. It will exec inside the pod, and take a heapdump and a histogram. This one is useful when you are encountering high memory issue in just a single pod, or if you just have one pod.