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

# -----------------------------
# Embedded Template Loading
# -----------------------------

load_template() {
    local start_marker="$1"
    local end_marker="$2"
    # Use sed to extract lines between markers (excluding the markers themselves)
    sed -n "/^${start_marker}\$/,/^${end_marker}\$/p" "$0" | sed '1d;$d'
}

template_bulk=$(load_template "__TEMPLATE_BULK__" "__END_TEMPLATE_BULK__")

# -----------------------------
# Main Script
# -----------------------------

~/ATLAS-toolkit/scripts/convertLammpsTrj.pl -b {input}box.bgf -l {input}equil.{rtemp2}K.prod.lammpstrj -t $(grep "TIMESTEP" {input}equil.{rtemp2}K.prod.lammpstrj | wc -l) -m 1 -o bgf -s {input}post.bgf

sed -i '/^CRYSTX/d' {input}post.bgf

~/ATLAS-toolkit/scripts/addBoxToBGF.pl {input}post.bgf {input}primer.bgf

~/ATLAS-toolkit/scripts/replicate.pl -b {input}primer.bgf -d '2 2 2' -s replicated{input}.bgf

~/ATLAS-toolkit/scripts/createLammpsInput.pl -b replicated{input}.bgf -f "~/ff/DREIDING2.21.ff" -s bulk{input}

echo "$template_bulk" > in.bulk{input}

# File names
lmp_equil_file=in.bulk{input}
lmp_data_file=data.bulk{input}
lmp_log_file=bulk{input}.log

# LAMMPS executable and parameters
PARALLEL="mpirun -n 64"
#Use your lammps directory
LMP="/home/rramji/codes/LAMMPS/speed_lammps/build_custom/lmp_rob -var rtemp {rtemp3} -var press 1"

# Echo job details
echo "LAMMPS dynamics of {input}bulk at {rtemp3}K"

# Run LAMMPS
$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var rtemp {rtemp3} -var press 1 -var ctemp {ctemp1}

exit 0 

# -----------------------------
# Embedded Template Definitions
# -----------------------------

#Bulk

__TEMPLATE_BULK__
units                real
atom_style           full
boundary             p p p
dielectric           1
special_bonds        lj/coul 0.0 0.0 1.0
                     
pair_style           lj/charmm/coul/long/opt 9 10.00000
bond_style           harmonic
angle_style          harmonic
dihedral_style       harmonic
improper_style       none
kspace_style         pppm 0.0001
                     
read_data            data.bulk{input}
                     
                     
                     
pair_modify          mix geometric
neighbor             2.0 multi
neigh_modify         every 2 delay 4 check yes one 3000
thermo_style         custom etotal ke temp pe ebond eangle edihed eimp evdwl ecoul elong press spcpu density
thermo_modify        line multi format float %14.6f flush yes
variable             input string in.bulk{input}
variable             sname string bulk{input}
                     
                     
timestep             0.5
                     
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
dump                 1 all custom 2000 ${sname}.heat.lammpstrj id type xu yu zu vx vy vz
fix                  4 all nvt temp 1.0 ${rtemp} 100.0
run                  200000
unfix                4
undump               1
                     
print                .
print                ================================================
print                "NPT equilibration dynamics"
print                ================================================
print                .
                     
fix                  2 all npt temp ${rtemp} ${rtemp} 100.0 iso 1.0 1.0 2000.0
fix recenter all recenter INIT INIT INIT
restart              100000 ${sname}.${rtemp}K.*.restart
dump                 1 all custom 5000 ${sname}.${rtemp}K.npt.lammpstrj id type xu yu zu vx vy vz
run                  3000000 # run for 1.5 ns
undump               1
unfix recenter
unfix                2

print                .
print                ================================================
print                "NVT production dynamics "
print                ================================================
print                .
                     
fix                  2 all nvt temp ${rtemp} ${rtemp} 100.0
fix recenter all recenter INIT INIT INIT
dump                 1 all custom 1000 ${sname}.${rtemp}K.prod.lammpstrj id type xu yu zu vx vy vz
run                  3000000 # run for 1.5 ns
unfix recenter
unfix                2
undump               1

print                .
print                =====================================
print                "NVT dynamics to cool system"
print                =====================================

dump                 1 all custom 1000 ${sname}.cool.lammpstrj id type xu yu zu vx vy vz
fix                  4 all nvt temp ${rtemp} ${ctemp} 100.0
run                  200000
unfix                4
undump               1

print                ================================================
print                "NPT equilibration dynamics "
print                ================================================

fix                  2 all npt temp ${ctemp} ${ctemp} 100.0 iso 1.0 1.0 2000
fix recenter all recenter INIT INIT INIT
restart              10000 ${sname}.${ctemp}K.*.restart
dump                 1 all custom 1000 ${sname}.${ctemp}K.npt.lammpstrj id type xu yu zu vx vy vz
run                  1000000 # run for 0.5 ns
unfix recenter
unfix                2
undump               1

print                .
print                ================================================
print                "NVT equilibration dynamics "
print                ================================================
print                .

fix                  2 all nvt temp ${ctemp} ${ctemp} 100.0
fix recenter all recenter INIT INIT INIT
dump                 1 all custom 10000 ${sname}.${ctemp}K.prod.lammpstrj id type xu yu zu vx vy vz
run                  1000000 # run for 0.5 ns
unfix recenter
unfix                2
undump               1
__END_TEMPLATE_BULK__
