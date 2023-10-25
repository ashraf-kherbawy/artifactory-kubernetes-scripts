#!/bin/bash

# Prompt for the pod name
read -p "Enter the pod's name: " POD_NAME

# Prompt for the namespace
read -p "Enter the namespace: " NAMESPACE

# Check if the NAMESPACE exists
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Namespace: $NAMESPACE exists."
else
    echo "Namespace $NAMESPACE does not exist. Exiting..."
    exit 1
fi

# Check if the pod exists
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo -e "Pod: $POD_NAME exists."
    echo
else
    echo "Pod $POD_NAME does not exist in NAMESPACE: $NAMESPACE. Exiting..."
    exit 1
fi

# Function to check if the kubectl process managed to execute successfully.
# First and second paramater are the relevant logs incase it works or not.
# Third paramater if it's passed as 0, then it's a critical process that failed (Mainly with heapdumps), thus the script will exit with code 1.
validate_procces() {

    if [ $? -eq 0 ]; then
        echo -e "$1"
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

echo -e "Creating local directory 'generated-heapdumps' to save the files in."
echo
mkdir ./generated-heapdumps

# Generating the heapdump and histogram in the container.
echo "Generating Heapdump.."
kubectl_exec 'export POD_NAME=$(cat /etc/hostname); /opt/jfrog/artifactory/app/third-party/java/bin/jmap -dump:file=/tmp/dump.$POD_NAME.hprof $(pidof java)'
validate_procces "Jmap executed successfully while generating Heapdump." "Failed to generate Heapdump.. Exiting" 0

echo "Generating Histogram.."
kubectl_exec 'export POD_NAME=$(cat /etc/hostname); /opt/jfrog/artifactory/app/third-party/java/bin/jmap -histo:file=/tmp/histo.$POD_NAME $(pidof java)'
validate_procces "Jmap executed successfully while generating Histogram." "Failed to generate Histogram.. Continuing as it's not as important as a Heapdump" 1

# Copying the heapdump and histogram to the local directory.
echo "Copying Heapdump to local directory (This could take up to five minutes).."
kubectl cp --retries=10 $NAMESPACE/$POD_NAME:/tmp/dump.$POD_NAME.hprof ./generated-heapdumps/dump.$POD_NAME.hprof -c artifactory 
validate_procces "Finished copying Heapdump to local directory." "Failed to copy Heapdump to local directory. Exiting without deleting the files.." 0 

echo "Copying Histogram to local directory.."
kubectl cp --retries=10 $NAMESPACE/$POD_NAME:/tmp/histo.$POD_NAME ./generated-heapdumps/histo.$POD_NAME -c artifactory 
validate_procces "Finished copying Histogram to local directory." "Failed to copy Histogram to local directory. Continuing.." 1

# Deleting the heapdump and histogram in the container.
echo "Deleting Heapdump inside $POD_NAME"
kubectl_exec 'export POD_NAME=$(cat /etc/hostname); rm /tmp/dump.$POD_NAME.hprof'
validate_procces "Deleted Heapdump successfully" "Failed to delete Heapdump." 1

echo "Deleting Histogram inside $POD_NAME"
kubectl_exec 'export POD_NAME=$(cat /etc/hostname); rm /tmp/histo.$POD_NAME'
validate_procces "Deleted Histogram successfully" "Failed to delete Histogram" 1


echo -e "Finished operation. Check your local directory for the following files:"
echo
echo "dump.$POD_NAME.hprof"
echo "histo.$POD_NAME"