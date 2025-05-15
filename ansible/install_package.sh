#!/bin/bash

# Check input arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 <package-name|update|upgrade> <group-name>"
  exit 1
fi

PACKAGE="$1"
GROUP="$2"

USER="sysadmin"
# Map group to user
if [[ "$GROUP" == "admin" ]]; then
  USER="admin_lead"
fi

LOGFILE="/var/log/${GROUP}.txt"
HOSTFILE="/tmp/${GROUP}_hosts.txt"
PLAYBOOK="install_package.yml"
SSH_KEY="~/.ssh/id_rsa"

# Check log file
if [ ! -f "$LOGFILE" ]; then
  echo "Error: Log file $LOGFILE not found."
  exit 2
fi

# Extract unique IPs
awk '{print $2}' "$LOGFILE" | sort -u > "$HOSTFILE"

# Run the Ansible playbook
ansible-playbook "$PLAYBOOK" \
  -i "$HOSTFILE" \
  -u "$USER" \
  --private-key "$SSH_KEY" \
  --extra-vars "pkg=$PACKAGE"
