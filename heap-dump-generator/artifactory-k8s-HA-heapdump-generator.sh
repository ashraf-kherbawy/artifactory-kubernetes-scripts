#!/bin/bash

# This script will detect all of your Artifactory pods, and go over them one by one, collecting heapdumps and
# histograms, copying them to a local directory called generated-heapdumps, and then deleting them.
# This script should be used when you have more than 1 Artifactory pod, and if you are having memory issues across all or multiple pods.

# Prompt the user for the helm release name
read -p "Enter the release name: " RELEASE

# Prompt the user for the namespace
read -p "Enter the namespace: " NAMESPACE

# Check if the namespace exists
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Namespace $NAMESPACE exists."
else
    echo "Namespace $NAMESPACE does not exist. Exiting..."
    exit 1
fi

# Check if a StatefulSet with the specified label exists in the provided NAMESPACE
STATEFULSET=$(kubectl get statefulset -n "$NAMESPACE" --selector=release="$RELEASE")
if [ -z "$STATEFULSET" ]; then
    echo "StatefulSet with label 'release=$RELEASE' does not exist in namespace $NAMESPACE. Exiting..."
    exit 1
fi
echo  "StatefulSet with label 'release=$RELEASE' exists in namespace $NAMESPACE."

# Function to check if the kubectl process managed to execute successfully.
# First and second paramater are the relevant logs incase it works or not.
# Third paramater if it's passed as 0, then it's a critical process that failed (Mainly with heapdumps), thus the script will exit with code 1.
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

# Function to handle the kubectl exec operations, which includes generating the dumps, and deleting them.
# Takes one paramater as the internal bash function to pass.
kubectl_exec() {
    kubectl exec -n "$NAMESPACE" -c artifactory "$POD_NAME" \
    -- bash -c "$1"
}

# Get the number of pods with names starting with the RELEASE name followed by a hyphen and a number
POD_NAMES=$(kubectl get pods -n "$NAMESPACE" | grep -E "^$RELEASE-[0-9]+" | awk '{print $1}')

# Check if there are pod deployed by the STATEFULSET 
if [ -z "$POD_NAMES" ]; then
    echo "No pods found with names starting with $RELEASE, even though Artifactory's Statefulset exists. Exiting.."
    exit 1
fi

echo "Detected the following Artifactory pods:"
echo
echo "$POD_NAMES"
echo
echo "Creating a local directory named './generated-heapdumps' to save the heapdumps at.."
echo
mkdir ./generated-heapdumps


# Generating the heapdump and histogram in the container for each pod.
for POD_NAME in $POD_NAMES; do

    echo "Generating Heapdump... Executing on Pod: $POD_NAME"
    kubectl_exec 'export POD_NAME=$(cat /etc/hostname); /opt/jfrog/artifactory/app/third-party/java/bin/jmap -dump:file=/tmp/dump.$POD_NAME.hprof $(pidof java)'
    validate_procces "Jmap executed successfully while generating Heapdump." "Failed to generate Heapdump.. Exiting" 0

    
    echo "Generating Histogram... Executing on Pod: $POD_NAME"
    kubectl_exec 'export POD_NAME=$(cat /etc/hostname); /opt/jfrog/artifactory/app/third-party/java/bin/jmap -histo:file=/tmp/histo.$POD_NAME $(pidof java)'
    validate_procces "Jmap executed successfully while generating Histogram." "Failed to generate Histogram.. Continuing as it's not as important as a Heapdump" 1 

done

echo "Finished executing Jmap. Now copying the files locally and cleaning up the container.."
echo

for POD_NAME in $POD_NAMES; do

    # Copying the heapdump and histogram to the local directory.
    echo "Copying $POD_NAME's Heapdump to local directory (This could take up to five minutes).."
    kubectl cp --retries=10 $NAMESPACE/$POD_NAME:/tmp/dump.$POD_NAME.hprof ./generated-heapdumps/dump.$POD_NAME.hprof -c artifactory 
    validate_procces "Finished copying Heapdump to local directory." "Failed to copy Heapdump to local directory. Exiting without deleting the files.." 0 

    echo "Copying $POD_NAME's Histogram to local directory.."
    kubectl cp --retries=10 $NAMESPACE/$POD_NAME:/tmp/histo.$POD_NAME ./generated-heapdumps/histo.$POD_NAME -c artifactory 
    validate_procces "Finished copying Histogram to local directory." "Failed to copy Histogram to local directory. Continuing.." 1

    # Deleting the heapdump and histogram in the container.
    echo "Deleting Heapdump inside $POD_NAME"
    kubectl_exec 'export POD_NAME=$(cat /etc/hostname); rm /tmp/dump.$POD_NAME.hprof'
    validate_procces "Deleted Heapdump successfully" "Failed to delete Heapdump." 1

    echo "Deleting Histogram inside $POD_NAME"
    kubectl_exec 'export POD_NAME=$(cat /etc/hostname); rm /tmp/histo.$POD_NAME'
    validate_procces "Deleted Histogram successfully" "Failed to delete Histogram" 1

    echo "Finished operating on Pod $POD_NAME."
    echo

done