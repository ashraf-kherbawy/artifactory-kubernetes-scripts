# Artifactory Kubernetes Threaddump Generator

This script was designed to collect 15 thread dumps, with an interval of 2 seconds, of Artifactory that is running in Kubernetes. This was made in mine to save time and effort.

## Usage

When running the script, it will prompt 2 arguments, namespace and pod name. The script will exec into the Artifactory container 15 times to generate a thread dump using JStack 15 times, with an interval of 2 seconds. The reason for 2 seconds is because kubectl exec takes on average 2-3 seconds everytime to reach the container, which makes it an over all 4-5 interval on average, which is good enough for thread dump generation.

Once the generation is done, the script will execute kubectl cp to copy the thread dumps to a local directory, and then a final prompt will ask if you want to keep the thread dumps inside the container or delete them. This is incase something goes wrong with the copy process, so you wouldn't want them to be deleted.