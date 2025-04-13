#!/bin/bash
#SBATCH --job-name={input}bulk_job    # Job name
#SBATCH --partition={partition}          # Partition name
#SBATCH --nodes={nodes}                   # Number of nodes
#SBATCH --ntasks-per-node={tasks}  # Number of tasks (MPI processes)
#SBATCH --time={time}               # Run time (hh:mm:ss)
#SBATCH --output={input}bulk_%j.out    # Standard output and error log
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

#For this to work and give meaningful results one needs a successfully completed bulk equilibration, with restart files. 

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
    # Use sed to extract lines between markers 
    sed -n "/^${start_marker}\$/,/^${end_marker}\$/p" "$0" | sed '1d;$d'
}

template_bulk2=$(load_template "__TEMPLATE_BULK2__" "__END_TEMPLATE_BULK2__")

# -------------------------------------------
# Main Script
# -------------------------------------------

echo "$template_deformation" > in.deformation{input}
lmp_equil_file=in.deformation{input}
lmp_restart_file=bulk{input}.{ctemp1}K.{final}.restart
lmp_log_file=deformation{input}.log

PARALLEL="mpirun -n 64"
#Use your lammps directory
LMP="/home/rramji/codes/LAMMPS/speed_lammps/build_custom/lmp_rob -var ctemp {ctemp1} -var stemp {stemp1} -var press 1"

echo "LAMMPS dynamics of {input}bulk at {stemp1}K"

$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var ctemp {ctemp1} -var stemp {stemp1} -var press 1

exit 0
# ------------

# -----------------------------
# Embedded Template Definitions
# -----------------------------

#Bulk

__TEMPLATE_BULK2__
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
kspace_style         pppm 0.0001
                     
read_restart         bulk{input}.{ctemp1}K.{final}.restart   
                     
pair_modify          mix geometric
neighbor             2.0 multi
neigh_modify         every 2 delay 4 check yes one 3000
thermo_style         custom etotal ke temp pe ebond eangle edihed eimp evdwl ecoul elong press spcpu density
thermo_modify        line multi format float %14.6f flush yes
variable             input string in.bulk{input}_2
variable             sname string bulk{input}_2
                     
                     
timestep             0.5

print                ================================================
print                "NPT equilibration dynamics "
print                ================================================

fix                  2 all npt temp ${ctemp} ${ctemp} 100.0 iso 1.0 1.0 2000
fix recenter all recenter INIT INIT INIT
restart              100000 ${sname}.${ctemp}K.*.restart
dump                 1 all custom 1000 ${sname}.${ctemp}K.npt.lammpstrj id type xu yu zu vx vy vz
run                  1000000 # run for 0.5 ns
unfix recenter
unfix                2
undump               1

print                .
print                =====================================
print                "NVT dynamics to heat system"
print                =====================================

dump                 1 all custom 1000 ${sname}.heat.lammpstrj id type xu yu zu vx vy vz
fix                  4 all npt temp ${ctemp} ${rtemp} 100.0 iso 1.0 1.0 2000
run                  100000
unfix                4
undump               1

print                .
print                ================================================
print                "NVT Equilibration dynamics "
print                ================================================
print                .

fix                  2 all nvt temp ${rtemp} ${rtemp} 100.0
fix recenter all recenter INIT INIT INIT
dump                 1 all custom 1000 ${sname}.${rtemp}K.prod.lammpstrj id type xu yu zu vx vy vz
run                  2000000 
unfix                2
unfix recenter
undump               1

print                .
print                =====================================
print                "NVT dynamics to cool system"
print                =====================================

dump                 1 all custom 1000 ${sname}.cool.lammpstrj id type xu yu zu vx vy vz
fix                  4 all npt temp ${rtemp} ${ctemp} 100.0 iso 1.0 1.0 2000
run                  100000
unfix                4
undump               1


print                ================================================
print                "NPT equilibration dynamics "
print                ================================================

fix                  2 all npt temp ${ctemp} ${ctemp} 100.0 iso 1.0 1.0 2000
fix recenter all recenter INIT INIT INIT
restart              100000 ${sname}.${ctemp}K.*.restart
dump                 1 all custom 1000 ${sname}.${ctemp}K.npt.lammpstrj id type xu yu zu vx vy vz
run                  2000000 # run for 0.5 ns
unfix recenter
unfix                2
undump               1
__END_TEMPLATE_BULK2__
