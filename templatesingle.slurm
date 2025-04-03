#!/bin/bash
#SBATCH --job-name={input}equil_job    # Job name
#SBATCH --partition={partition}          # Partition name
#SBATCH --nodes={nodes}                   # Number of nodes
#SBATCH --ntasks-per-node={tasks}  # Number of tasks (MPI processes)
#SBATCH --time={time}               # Run time (hh:mm:ss)
#SBATCH --output={input}equil_%j.out    # Standard output and error log
#SBATCH --account={account}
#SBATCH --mail-type=all

module purge
module load slurm cpu/0.15.4 gcc/9.2.0 openmpi
module load cmake
module load openblas
module load amdfftw
module load gsl
module load netlib-scalapack
module load netlib-lapack
module load vmd/1.9.3
module load gcc/10.2.0
module load openbabel/3.0.0

# -----------------------------------------------------------------------------------
# Embedded Template Loading
# -----------------------------------------------------------------------------------

load_template() {
    local start_marker="$1"
    local end_marker="$2"
    sed -n "/^${start_marker}\$/,/^${end_marker}\$/p" "$0" | sed '1d;$d'
}

template_minimize=$(load_template "__TEMPLATE_MINIMIZE__" "__END_TEMPLATE_MINIMIZE__")
template_tcl=$(load_template "__TEMPLATE_TCL__" "__END_TEMPLATE_TCL__")


# -----------------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------------


obabel -imol2 {input}.mol2 -omol2 -O{input}o.mol2

sed -i -e 's/O\.3/O_3/g' \
       -e 's/C\.3/C_3/g' \
       -e 's/N\.3/N_3/g' \
       -e 's/H       1  RES1/H_      1  RES1/' \
       {input}o.mol2

sed -i 's/H_HB/H_/g' {input}o.mol2

~/ATLAS-toolkit/scripts/createLammpsInput.pl -b {input}o.mol2 -f "~/ATLAS-toolkit/ff/UFF.ff" -t min -s {input}

max=$(awk '/xlo xhi|ylo yhi|zlo zhi/ {
    for(i=1; i<=NF; i++){
        if($i ~ /^-?[0-9]+\.[0-9]+$/){
            n = ($i < 0 ? -$i : $i)   
            if(n > max) { max = n }
        }
    }
} END { printf "%.6f", max }' data.{input})

sed -Ei '/(xlo xhi|ylo yhi|zlo zhi)/ s/(-?)[0-9]+\.[0-9]+/\1'"$max"'/g' data.{input}

module load gcc/9.2.0
module load netlib-lapack

echo "$template_minimize" > in.{input}

lmp_equil_file=in.{input}
lmp_data_file=data.{input}
lmp_log_file={input}.log

PARALLEL="mpirun -n 64"
#Use your lammps directory
LMP="/home/rramji/codes/LAMMPS/speed_lammps/build_custom/lmp_rob -var rtemp {rtemp1} -var press 1"

rtemp="{rtemp1}"

echo "LAMMPS dynamics of {input} at {rtemp1}K"

$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var rtemp {rtemp1} -var press 1

mv {input}.mol2 {input}_original.mol2
mv {input}o.mol2 {input}.mol2

temp_tcl=$(mktemp ./template.tcl.XXXX)
echo "$template_tcl" > "$temp_tcl"
vmd -dispdev text -e "$temp_tcl" -eofexit -args "$rtemp" "{input}"
rm -f "$temp_tcl"

module load gcc/10.2.0
module load openbabel/3.0.0

obabel -imol2 {input}vmd.mol2 -obgf -O{input}_equil.bgf

exit 0

# --------------------------------------------------------------------------------------------------
# Embedded Template Definitions
# --------------------------------------------------------------------------------------------------

#Minimization

__TEMPLATE_MINIMIZE__
units                real
atom_style           full
boundary             p p p
dielectric           1
special_bonds        lj/coul 0.0 0.0 1.0

# UFF force field styles, cut pair_style to deal with large initial box volume
pair_style           lj/cut/coul/cut 9 10
bond_style           harmonic
angle_style          harmonic
dihedral_style       harmonic
improper_style       umbrella
#kspace_style         pppm 0.0001
                     
read_data            data.{input}                     
                     
pair_modify          mix geometric
neighbor             2.0 multi
# Increase neigh one to 3000 from default 2000 (need longer max neighbor list size)
neigh_modify         every 2 delay 4 check yes one 3000
thermo_style         custom etotal ke temp pe ebond eangle edihed eimp evdwl ecoul elong press spcpu density
thermo_modify        line multi format float %14.6f flush yes
variable             input string in.{input}
variable             sname string {input}
                     
                     
timestep             1
                     
print                .
print                ==========================================
print                "500 steps CG Minimization"
print                ==========================================
print                .

dump                 1 all custom 25 ${sname}.min.lammpstrj id type xu yu zu vx vy vz
thermo               10
min_style            sd
minimize             1.0e-4 1.0e-4 500 5000
min_style            cg
minimize             1.0e-4 1.0e-4 500 5000
#now                 minimize the entire system
minimize             1.0e-4 1.0e-4 500 5000
undump               1


print                .
print                =====================================
print                "NVT dynamics to heat system"
print                =====================================
print                .

reset_timestep       0
fix                  shakeH all shake 0.0001 20 500 m 1.0079
velocity             all create 0.0 12345678 dist uniform
thermo               100
dump                 1 all custom 1000 ${sname}.heat.lammpstrj id type xu yu zu vx vy vz
fix                  4 all nvt temp 1.0 ${rtemp} 100.0
fix 1 all balance 100 0.9 shift xyz 20 1.1 out tmp.balance
run                  100000
unfix                4
undump               1

print                .
print                ================================================
print                "NVT production dynamics "
print                ================================================
print                .

fix                  2 all nvt temp ${rtemp} ${rtemp} 100.0
fix recenter all recenter INIT INIT INIT
restart              500000 ${sname}.${rtemp}K.*.restart
dump                 1 all custom 10000 ${sname}.${rtemp}K.nvt.lammpstrj id type xu yu zu vx vy vz
run                  5000000 # run for 15 ns
undump 1
unfix                2
unfix recenter

print                .
print                ================================================
print                "NPT equilibration dynamics."
print                ================================================
print                .

fix                  2 all npt temp ${rtemp} ${rtemp} 100.0 iso 1.0 1.0 2000.0
fix recenter all recenter INIT INIT INIT
dump                 1 all custom 1000 ${sname}.${rtemp}K.npt.lammpstrj id type xu yu zu vx vy vz
run                  1000000 # run for 1 ns
unfix recenter
unfix                2
undump               1

print                .
print                ================================================
print                "NVT production dynamics "
print                ================================================
print                .

fix                  2 all nvt temp ${rtemp} ${rtemp} 100.0
fix recenter all recenter INIT INIT INIT
dump                 1 all custom 1000 ${sname}.${rtemp}K.prod.lammpstrj id type xu yu zu vx vy vz
run                  1000000 # run for 15 ns
unfix                2
unfix recenter
undump               1
__END_TEMPLATE_MINIMIZE__

#Tcl

__TEMPLATE_TCL__
if {$argc < 2} {
    puts "Usage: ./script.tcl rtemp mol2"
    exit 1
}
set rtemp [lindex $argv 0]
set prefix [lindex $argv 1]

puts "Basename without .mol2: $prefix"

package require topotools

mol new ${prefix}.mol2 type mol2 waitfor all

mol addfile "${prefix}.${rtemp}K.npt.lammpstrj" type lammpstrj waitfor all

# Get the number of frames
set nf [molinfo top get numframes]
# Go to last frame
animate goto $nf

# Get atom coordinates from last frame and update
set sel [atomselect top all frame last]
$sel writemol2 ${prefix}vmd.mol2
$sel delete

# Exit VMD
quit
__END_TEMPLATE_TCL__
