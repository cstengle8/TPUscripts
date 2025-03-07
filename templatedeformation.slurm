#!/bin/bash
#SBATCH --job-name={input}deformation_job    # Job name
#SBATCH --partition={partition}          # Partition name
#SBATCH --nodes={nodes}                   # Number of nodes
#SBATCH --ntasks-per-node={tasks}  # Number of tasks (MPI processes)
#SBATCH --time={time}               # Run time (hh:mm:ss)
#SBATCH --output={input}deformation_%j.out    # Standard output and error log
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

# -------------------------------------------
# Embedded Template Loading
# -------------------------------------------

restart_dir="./"

cd "$restart_dir" || { echo "Error: Cannot change to directory $restart_dir"; exit 1; }

#For this to work and give meaningful results one needs a successfully completed bulk equilibration, with plentiful restart files. 

get_max_final() {
  local max=0
  for file in bulk{input}.{ctemp1}K.*.restart; do
    # Remove the .restart suffix and extract the integer after the last dot
    local num="${file%.restart}"
    num="${num##*.}"
    # Compare and update max if needed
    (( num > max )) && max=$num
  done
  final=$max
  echo "$final"
}
get_max_final

sed -i "s/{final}/$final/g" "$0"

load_template() {
    local start_marker="$1"
    local end_marker="$2"
    # Use sed to extract lines between markers (excluding the markers themselves)
    sed -n "/^${start_marker}\$/,/^${end_marker}\$/p" "$0" | sed '1d;$d'
}

template_deformation=$(load_template "__TEMPLATE_DEFORMATION__" "__END_TEMPLATE_DEFORMATION__")

# -------------------------------------------
# Main Script
# -------------------------------------------

echo "$template_deformation" > in.deformation{input}
# File names
lmp_equil_file=in.deformation{input}
lmp_restart_file=bulk{input}.{ctemp1}K.{final}.restart
lmp_log_file=deformation{input}.log

# LAMMPS executable and parameters
PARALLEL="mpirun -n 64"
#Use your lammps directory
LMP="/home/rramji/codes/LAMMPS/speed_lammps/build_custom/lmp_rob -var ctemp {ctemp1} -var stemp {stemp1} -var press 1"

# Echo job details
echo "LAMMPS dynamics of {input}bulk at {stemp1}K"

# Run LAMMPS
$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var ctemp {ctemp1} -var stemp {stemp1} -var press 1

exit 0
# -------------------------------------------
# Embedded Template Definitions
# -------------------------------------------

#Deformation

__TEMPLATE_DEFORMATION__
units                real
atom_style           full
boundary             p p p
dielectric           1
special_bonds        lj/coul 0.0 0.0 1.0

pair_style           lj/charmm/coul/long/opt 9 10.00000
bond_style           harmonic
angle_style          harmonic
dihedral_style       harmonic
improper_style       umbrella
kspace_style         pppm 0.00001

read_restart         bulk{input}.{ctemp1}K.{final}.restart

pair_modify          mix geometric
neighbor             2.0 multi
neigh_modify         every 2 delay 4 check yes
thermo_style         custom etotal ke temp pe ebond eangle edihed eimp evdwl ecoul elong press spcpu density
thermo_modify        line multi format float %14.6f flush yes
variable             input string in.deformation{input}
variable             sname string deformation{input}


timestep             1

print                .
print                =====================================
print                "NVT dynamics to change temperature"
print                =====================================
thermo               100
dump                 1 all custom 1000 ${sname}.cool.lammpstrj id type xu yu zu vx vy vz
fix                  4 all nvt temp ${ctemp} ${stemp} 100.0
run                  50000
unfix                4
undump               1

print                ================================================
print                "NPT equilibration dynamics "
print                ================================================

fix                  2 all npt temp ${stemp} ${stemp} 100.0 iso 1.0 1.0 2000
fix recenter all recenter INIT INIT INIT
restart              100000 ${sname}.${stemp}K.*.restart
dump                 1 all custom 1000 ${sname}.${stemp}K.npt.lammpstrj id type xu yu zu vx vy vz
run                  1000000 # run for 1 ns
unfix recenter
unfix                2
undump               1


#####################################################
# Uniaxial Tensile Deformation
run 0
variable tmp equal "lx"
variable L0 equal ${tmp}
variable strain equal "(lx - v_L0)/v_L0"
variable p1 equal "v_strain"
variable p2 equal "-pxx/10000*1.01325"
variable p3 equal "-pyy/10000*1.01325"
variable p4 equal "-pzz/10000*1.01325"
variable p5 equal "lx"
variable p6 equal "ly"
variable p7 equal "lz"
variable p8 equal "temp"
variable t2 equal "epair"
variable t3 equal "ebond"
variable t4 equal "eangle"
variable t5 equal "edihed"
fix                  shakeH all shake 0.0001 20 500 m 1.0079
fix		1 all npt temp 100 100 50 y 0 0 1000 z 0 0 1000 drag 2
fix		2 all deform 1 x erate 1e-6 units box remap x
fix def1 all print 100 "${p1} ${p2} ${p3} ${p4} ${p5} ${p6} ${p7} ${p8}" file ${sname}.def1.txt screen no
fix def2 all print 100 "${p1} ${t2} ${t3} ${t4} ${t5}" file ${sname}.def2.txt screen no
#thermo_style	custom step temp pxx pyy pzz lx ly lz epair ebond eangle edihed
thermo_style custom etotal ke temp pe ebond eangle edihed eimp evdwl ecoul elong press spcpu pxx pyy pzz lx ly lz
thermo_modify        line multi format float %14.6f flush yes
dump       1 all custom 10000 ${sname}.${stemp}.deform.lammpstrj id type xu yu zu vx vy vz
thermo          100
timestep	1
reset_timestep	0
run		3000000
unfix 1
unfix 2
unfix def1
unfix def2

print "All done"
__END_TEMPLATE_DEFORMATION__
