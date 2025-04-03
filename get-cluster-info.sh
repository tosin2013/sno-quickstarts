#!/bin/bash

# Script to gather OpenShift cluster and host information
# This script retrieves the current OpenShift context and host details
# and stores them in memory for further processing

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get IP address
get_ip_address() {
    if command_exists ip; then
        ip route get 1 | awk '{print $7;exit}'
    elif command_exists ifconfig; then
        ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
    else
        echo "Could not determine IP address"
    fi
}

# Function to detect infrastructure
detect_infrastructure() {
    # Check for AWS
    if curl -s http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        echo "AWS"
    # Check for Azure
    elif curl -s http://169.254.169.254/metadata/instance >/dev/null 2>&1; then
        echo "Azure"
    # Check for GCP
    elif curl -s http://metadata.google.internal/computeMetadata/v1/ >/dev/null 2>&1; then
        echo "GCP"
    # Check for OpenStack
    elif curl -s http://169.254.169.254/openstack/ >/dev/null 2>&1; then
        echo "OpenStack"
    # Check for vSphere
    elif command_exists vmware-toolbox-cmd >/dev/null 2>&1; then
        echo "vSphere"
    # Check for bare metal
    elif command_exists dmidecode >/dev/null 2>&1 && sudo dmidecode -s system-manufacturer | grep -i "bare metal" >/dev/null 2>&1; then
        echo "Bare Metal"
    # Check for SNO (Single Node OpenShift)
    elif oc get nodes | grep -q "NotReady"; then
        echo "Single Node OpenShift (SNO)"
    else
        echo "Unknown"
    fi
}

# Check if oc command exists
if ! command_exists oc; then
    echo "Error: OpenShift CLI (oc) is not installed"
    exit 1
fi

# Check if we're logged into OpenShift
if ! oc whoami >/dev/null 2>&1; then
    echo "Error: Not logged into OpenShift. Please run 'oc login' first"
    exit 1
fi

# Get OpenShift context information
echo "Gathering OpenShift cluster information..."
OC_CLUSTER_URL=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')
OC_USER=$(oc whoami)
OC_PROJECT=$(oc project -q)
OC_CLUSTER_NAME=$(oc config view --minify -o jsonpath='{.clusters[0].name}')

# Get infrastructure information
echo "Detecting infrastructure..."
INFRA_TYPE=$(detect_infrastructure)

# Get host information
echo "Gathering host information..."
HOSTNAME=$(hostname)
HOST_IP=$(get_ip_address)
HOST_OS=$(uname -s)
HOST_ARCH=$(uname -m)

# Store information in associative array for easy access
declare -A CLUSTER_INFO=(
    ["cluster_url"]="$OC_CLUSTER_URL"
    ["user"]="$OC_USER"
    ["project"]="$OC_PROJECT"
    ["cluster_name"]="$OC_CLUSTER_NAME"
    ["infrastructure"]="$INFRA_TYPE"
    ["hostname"]="$HOSTNAME"
    ["ip_address"]="$HOST_IP"
    ["os"]="$HOST_OS"
    ["architecture"]="$HOST_ARCH"
)

# Export variables for use in other scripts
export OC_CLUSTER_URL
export OC_USER
export OC_PROJECT
export OC_CLUSTER_NAME
export INFRA_TYPE
export HOSTNAME
export HOST_IP
export HOST_OS
export HOST_ARCH

# Print summary of gathered information
echo -e "\n=== OpenShift Cluster Information ==="
echo "Cluster URL: ${CLUSTER_INFO[cluster_url]}"
echo "Cluster Name: ${CLUSTER_INFO[cluster_name]}"
echo "Current User: ${CLUSTER_INFO[user]}"
echo "Current Project: ${CLUSTER_INFO[project]}"
echo "Infrastructure: ${CLUSTER_INFO[infrastructure]}"
echo -e "\n=== Host Information ==="
echo "Hostname: ${CLUSTER_INFO[hostname]}"
echo "IP Address: ${CLUSTER_INFO[ip_address]}"
echo "Operating System: ${CLUSTER_INFO[os]}"
echo "Architecture: ${CLUSTER_INFO[architecture]}"

# Optional: Export to JSON file
if command_exists jq; then
    echo -e "\nExporting information to cluster-info.json..."
    jq -n \
        --arg url "${CLUSTER_INFO[cluster_url]}" \
        --arg name "${CLUSTER_INFO[cluster_name]}" \
        --arg user "${CLUSTER_INFO[user]}" \
        --arg project "${CLUSTER_INFO[project]}" \
        --arg infra "${CLUSTER_INFO[infrastructure]}" \
        --arg hostname "${CLUSTER_INFO[hostname]}" \
        --arg ip "${CLUSTER_INFO[ip_address]}" \
        --arg os "${CLUSTER_INFO[os]}" \
        --arg arch "${CLUSTER_INFO[architecture]}" \
        '{
            "openshift": {
                "cluster_url": $url,
                "cluster_name": $name,
                "user": $user,
                "project": $project,
                "infrastructure": $infra
            },
            "host": {
                "hostname": $hostname,
                "ip_address": $ip,
                "os": $os,
                "architecture": $arch
            }
        }' > cluster-info.json
    echo "Information exported to cluster-info.json"
fi 