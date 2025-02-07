#!/bin/bash

get_input() {
    local prompt="$1"
    local default="$2"
    local result

    result=$(whiptail --inputbox "$prompt" 8 60 "$default" --title "Simulation Variables" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        echo "User cancelled."
        exit 1
    fi
    echo "$result"
}

prefix=$(get_input "Enter Job Prefix:" "")
rtemp1=$(get_input "Enter UFF equilibration temp:" "")
rtemp2=$(get_input "Enter single chain equilibration temp:" "")
rtemp3=$(get_input "Enter bulk chain heating temp:" "")
ctemp=$(get_input "Enter bulk chain equilibration temp:" "")
partition=$(get_input "Enter Partition:" "")
nodes=$(get_input "Enter Nodes:" "")
tasks=$(get_input "Enter Tasks/Node:" "")
walltime=$(get_input "Enter Walltime (hh:mm:ss):" "")
account=$(get_input "Enter Account:" "")

echo "You entered:"
echo "  Job Prefix:    $prefix"
echo "  rtemp1:        $rtemp1"
echo "  rtemp2:        $rtemp2"
echo "  rtemp3:        $rtemp3"
echo "  ctemp:         $ctemp"
echo "  Partition:     $partition"
echo "  Nodes:         $nodes"
echo "  Tasks/Node:    $tasks"
echo "  Walltime:      $walltime"
echo "  Account:       $account"

for var in prefix rtemp1 rtemp2 rtemp3 ctemp partition nodes tasks walltime account; do
    if [ -z "${!var}" ]; then
        echo "$var is empty. Aborting."
        exit 1
    fi
done

output_single="${prefix}singlechain.slurm"
sed "s/{input}/$prefix/g" templatesingle.slurm > "$output_single"
sed -i "s/{rtemp1}/$rtemp1/g" "$output_single"
sed -i "s/{rtemp2}/$rtemp2/g" "$output_single"
sed -i "s/{partition}/$partition/g" "$output_single"
sed -i "s/{nodes}/$nodes/g" "$output_single"
sed -i "s/{tasks}/$tasks/g" "$output_single"
sed -i "s/{walltime}/$walltime/g" "$output_single"
sed -i "s/{account}/$account/g" "$output_single"

output_bulk="${prefix}bulk.slurm"
sed "s/{input}/$prefix/g" templatebulk.slurm > "$output_bulk"
sed -i "s/{rtemp3}/$rtemp3/g" "$output_bulk"
sed -i "s/{ctemp}/$ctemp/g" "$output_bulk"
sed -i "s/{partition}/$partition/g" "$output_bulk"
sed -i "s/{nodes}/$nodes/g" "$output_bulk"
sed -i "s/{tasks}/$tasks/g" "$output_bulk"
sed -i "s/{walltime}/$walltime/g" "$output_bulk"
sed -i "s/{account}/$account/g" "$output_bulk"

output_min="${prefix}template.minimize"
sed "s/{input}/$prefix/g" template.minimize > "$output_min"

output_equil="${prefix}template.equil"
sed "s/{input}/$prefix/g" template.equil > "$output_equil"

output_bulk_template="${prefix}template.bulk"
sed "s/{input}/$prefix/g" template.bulk > "$output_bulk_template"

echo "Template files created:"
echo "  $output_single"
echo "  $output_bulk"
echo "  $output_min"
echo "  $output_equil"
echo "  $output_bulk_template"

read -p "Press any key to exit..."
