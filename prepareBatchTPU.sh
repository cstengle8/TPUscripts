#!/bin/bash

get_input() {
    local prompt="$1"
    local default="$2"
    local result

    result=$(whiptail --inputbox "$prompt" 8 60 "$default" --title "Simulation Variables" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        echo "User cancelled." >&2
        exit 1
    fi
    if [ -z "$result" ]; then
        echo "No input provided." >&2
        exit 1
    fi
    echo "$result"
}

prefix=$(get_input "Enter Job Prefix:" "")
rtemp1=$(get_input "Enter UFF equilibration temp (K):" "300")
rtemp2=$(get_input "Enter single chain equilibration temp (K):" "800")
rtemp3=$(get_input "Enter bulk chain heating temp (K):" "1200")
ctemp=$(get_input "Enter bulk chain equilibration temp (K):" "300")
partition=$(get_input "Enter Partition:" "shared")
nodes=$(get_input "Enter Nodes:" "1")
tasks=$(get_input "Enter Tasks/Node:" "64")
walltime=$(get_input "Enter Walltime (hh:mm:ss):" "48:00:00")
account=$(get_input "Enter Account:" "csd799")


for var in prefix rtemp1 rtemp2 rtemp3 ctemp partition nodes tasks walltime account; do
    if [ -z "${!var}" ]; then
        echo "Variable '$var' is empty. Aborting." >&2
        exit 1
    fi
done


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


export prefix rtemp1 rtemp2 rtemp3 ctemp partition nodes tasks walltime account

output_single="${prefix}singlechain.slurm"
perl -pe '
  s/\{input\}/$ENV{"prefix"}/g;
  s/\{rtemp1\}/$ENV{"rtemp1"}/g;
  s/\{rtemp2\}/$ENV{"rtemp2"}/g;
  s/\{partition\}/$ENV{"partition"}/g;
  s/\{nodes\}/$ENV{"nodes"}/g;
  s/\{tasks\}/$ENV{"tasks"}/g;
  s/\{time\}/$ENV{"walltime"}/g;
  s/\{account\}/$ENV{"account"}/g;
' templatesingle.slurm > "$output_single"

output_bulk="${prefix}bulk.slurm"
perl -pe '
  s/\{input\}/$ENV{"prefix"}/g;
  s/\{rtemp2\}/$ENV{"rtemp2"}/g;
  s/\{rtemp3\}/$ENV{"rtemp3"}/g;
  s/\{ctemp1\}/$ENV{"ctemp"}/g;
  s/\{partition\}/$ENV{"partition"}/g;
  s/\{nodes\}/$ENV{"nodes"}/g;
  s/\{tasks\}/$ENV{"tasks"}/g;
  s/\{time\}/$ENV{"walltime"}/g;
  s/\{account\}/$ENV{"account"}/g;
' templatebulk.slurm > "$output_bulk"

echo "Template files created:"
echo "  $output_single"
echo "  $output_bulk"

read -p "Press any key to exit..."
