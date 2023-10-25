#!/bin/bash

# Prompt for the pod name
read -p "Enter the pod's name: " POD_NAME

# Prompt for the NAMESPACE
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
    echo "Pod: $POD_NAME exists."
    echo
else
    echo "Pod $POD_NAME does not exist in NAMESPACE: $NAMESPACE. Exiting..."
    exit 1
fi

# Function to check if the kubectl process managed to execute successfully.
# First and second paramater are the relevant logs incase it works or not.
# Third paramater if it's passed as 0, then it's a critical process that failed (Mainly generating the thread dumps), thus the script will exit with code 1.
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

echo "Creating local directory 'generated-thread-dumps' to save the files in."
mkdir ./generated-thread-dumps
echo

# Generating the threaddumps inside the container
echo "Generating 15 thread dumps with 2 second interval only, because kubectl exec takes a second or two to fully execute.."
echo
for ((i = 1; i <= 15; i++)); do
    # Add a 2-second wait at the end of each iteration
    echo "Waiting two seconds.."
    echo
    sleep 2
    echo "Generating thread dump: $i"
    kubectl_exec '/opt/jfrog/artifactory/app/third-party/java/bin/jstack -l $(pidof java) > /tmp/dump.$(date +%Y%m%d%H%M%S).td'
    validate_procces "JStack executed succesfully." "JStack was unable to generate any or all threadumps. Exiting.." 0
done

# Save a list of all of the existing thread dumps inside the container in a variable
THREAD_DUMP_FILES=$(kubectl exec -n "$NAMESPACE" -c artifactory "$POD_NAME" -- ls /tmp/ | grep 'dump.*.td')

# Moving all of the dumps to local directory
echo "Moving Thread dumps from the container to local directory.."
echo

for FILE in $THREAD_DUMP_FILES; do
    echo "Moving Thread dump: $FILE"
    kubectl cp --retries=5 $NAMESPACE/$POD_NAME:/tmp/$FILE ./generated-thread-dumps/$FILE -c artifactory
    validate_procces 'Thread dump moved successfuly' 'Kubectl cp failed to copy the current thread dump to local directory. A prompt will be given after this process to not delete the thread dumps.' 1
done

# A final prompt to check if you want to delete the threads. This is incase something went bad with the copy process, and it didn't
# copy any or some of the thread dumps, so you can still have them in the container and try to copy them again.
read -p "Kubectl cp finished executing. Do you want to delete the thread dumps inside the container? (Insert 'true' if yes ): " DELETE_DUMPS

if [ "$DELETE_DUMPS" == "true" ]; then
    echo "Deleting thread dumps.."
    kubectl_exec "rm /tmp/dump.*.td"
    validate_procces "Successfully deleted the thread dumps inside the container." "Failed to delete thread dumps.." 1
fi

echo "Operation finished successfully."