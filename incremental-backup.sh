#!/bin/bash
#
# Autorship:XAASABLITY Product  (Copyleft: all rights reversed).
# Tested by: Sahul Hameed (Sr.Devops Support Engineer)
# Source the openrc file with the correct path
source /root/.openrc
# Initialize an array to store VM names
vmnames=()
date=$(date +%Y-%m-%d)
# Set the start and end index for VMs
start=0
end=5
# Get VM names
while IFS= read -r vm; do
    vmnames+=("$vm")
done < <(openstack --insecure server list --all-projects --long | awk 'NR>=4 {print $4}')

for i in "${vmnames[@]:start:end}"; do

    # Get VM IDs for the instance
    vm_ids=($(nova --insecure list --all-tenants --status=Active | grep "$i" | awk '{print $2}'))
    
    # Create a directory for the VM backup
    backup_dir="/opt/$i"

    # Check if the backup directory exists, and create if not
    if [[ ! -e "$backup_dir" ]]; then
        mkdir -p "$backup_dir"
    fi
    for j in "${vm_ids[@]}"; do
        # Reset the array for each VM
        rbd_ids=($(rbd ls -p vms | grep "$j"_disk))

        for ID in "${rbd_ids[@]}"; do
            # Check if the parent snapshot exists
            if [[ -z $(rbd snap ls vms/$ID) ]]; then
              # If there are no existing snapshots for the RBD volume
              echo "INFO : no snapshots found for this rbd image"
            else
                # Fetch the original snapshot name
                parent_snap=$(rbd snap ls vms/$ID | awk 'NR>=2 {print $2}' | head -n 1)
                echo "INFO : found previous snapshots for this rbd image, doing diff"
                # Create a new snapshot with the current date
                rbd snap create vms/$ID@$date
                # Export Incremental data since the parent snapshot to end snapshot
                rbd export-diff --rbd-concurrent-management-ops 120 --from-snap $parent_snap vms/$ID@$date "$backup_dir/$ID-$date.img"
                # Remove the snapshot
                rbd snap rm vms/$ID@$date
            fi
        done
    done
done
