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

# -----------------------------
# Embedded Template Loading
# -----------------------------

load_template() {
    local start_marker="$1"
    local end_marker="$2"
    # Use sed to extract lines between markers (excluding the markers themselves)
    sed -n "/^${start_marker}\$/,/^${end_marker}\$/p" "$0" | sed '1d;$d'
}

template_minimize=$(load_template "__TEMPLATE_MINIMIZE__" "__END_TEMPLATE_MINIMIZE__")
template_equil=$(load_template "__TEMPLATE_EQUIL__" "__END_TEMPLATE_EQUIL__")
template_tcl=$(load_template "__TEMPLATE_TCL__" "__END_TEMPLATE_TCL__")


# -----------------------------
# Main Script
# -----------------------------


obabel -imol2 {input}.mol2 -omol2 -O{input}o.mol2

sed -i -e 's/O\.3/O_3/g' \
       -e 's/C\.3/C_3/g' \
       -e 's/N\.3/N_3/g' \
       -e 's/H       1  RES1/H_      1  RES1/' \
       {input}o.mol2

sed -i 's/H_HB/H_/g' {input}o.mol2

~/ATLAS-toolkit/scripts/createLammpsInput.pl -b {input}o.mol2 -f "~/ATLAS-toolkit/ff/UFF.ff" -t min -s {input}

module load gcc/9.2.0
module load netlib-lapack

echo "$template_minimize" > in.{input}

# File names
lmp_equil_file=in.{input}
lmp_data_file=data.{input}
lmp_log_file={input}.log

# LAMMPS executable and parameters
PARALLEL="mpirun -n 64"
#Use your lammps directory
LMP="/home/rramji/codes/LAMMPS/speed_lammps/build_custom/lmp_rob -var rtemp {rtemp1} -var press 1"

rtemp="{rtemp1}"

# Echo job details
echo "LAMMPS dynamics of {input} at {rtemp1}K"

# Run LAMMPS
$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var rtemp (rtemp1) -var press 1

temp_tcl=$(mktemp ./template.tcl.XXXX)
echo "$template_tcl" > "$temp_tcl"
vmd -dispdev text -e "$temp_tcl" -eofexit -args "$rtemp" "{input}"
rm -f "$temp_tcl"

module load gcc/10.2.0
module load openbabel/3.0.0

obabel -imol2 {input}vmd.mol2 -obgf -O{input}min.bgf

~/ATLAS-toolkit/scripts/autoType.pl -i {input}min.bgf -f ~/ATLAS-toolkit/ff/DREIDING2.21.ff -t bgf -s {input}typed.bgf

sed -i '/^CRYSTX/d' {input}typed.bgf

~/ATLAS-toolkit/scripts/addBoxToBGF.pl {input}typed.bgf {input}box.bgf

~/ATLAS-toolkit/scripts/createLammpsInput.pl -b {input}box.bgf -f ~/ATLAS-toolkit/ff/DREIDING2.21.ff -s {input}equil

echo "$template_equil" > in.{input}equil

module load gcc/9.2.0
module load netlib-lapack
# File names
lmp_equil_file=in.{input}equil
lmp_data_file=data.{input}equil
lmp_log_file={input}equil.log
#Use your Lammps directory
LMP="/home/rramji/codes/LAMMPS/speed_lammps/build_custom/lmp_rob -var rtemp {rtemp2} -var press 1"

# Echo job details
echo "LAMMPS dynamics of {input}equil at {rtemp2}K"

# Run LAMMPS
$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var rtemp {rtemp2} -var press 1

exit 0

# -----------------------------
# Embedded Template Definitions
# -----------------------------

#Minimization

__TEMPLATE_MINIMIZE__
units                real
atom_style           full
boundary             p p p
dielectric           1
special_bonds        lj/coul 0.0 0.0 1.0
                     
pair_style           lj/charmm/coul/long/opt 13 14.00000
bond_style           harmonic
angle_style          cosine/squared
dihedral_style       harmonic
improper_style       none
kspace_style         pppm 0.001
                     
read_data            data.{input}
                     
                     
                     
pair_modify          mix geometric
neighbor             2.0 multi
neigh_modify         every 1 delay 0 check yes one 3000
thermo_style         multi
thermo_modify        line multi format float %14.6f flush yes
variable             input string in.TPU4
variable             sname string TPU4
                     
                     
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

print                ================================================
print                "NPT equilibration dynamics "
print                ================================================

fix                  2 all npt temp ${rtemp} ${rtemp} 100.0 iso 1.0 1.0 2000
fix recenter all recenter INIT INIT INIT
restart              10000 ${sname}.1000K.*.restart
dump                 1 all custom 1000 ${sname}.${rtemp}K.npt.lammpstrj id type xu yu zu vx vy vz
run                  1000000 # run for 1 ns
unfix recenter
unfix                2
undump               1
__END_TEMPLATE_MINIMIZE__

#Equilibration

__TEMPLATE_EQUIL__
units                real
atom_style           full
boundary             p p p
dielectric           1
special_bonds        lj/coul 0.0 0.0 1.0
                     
pair_style           lj/cut/coul/cut 15 20
bond_style           harmonic
angle_style          harmonic
dihedral_style       harmonic
improper_style       umbrella
#kspace_style         pppm 0.0001

                     
read_data            data.{input}equil
                     
                     
                     
pair_modify          mix geometric
neighbor             2.0 multi
neigh_modify         every 1 delay 0 check yes one 7000
thermo_style custom etotal ke temp pe ebond eangle edihed eimp evdwl ecoul elong press spcpu density
thermo_modify        line multi format float %14.6f flush yes
variable             input string in.TPU4equil
variable             sname string TPU4equil
                     
                     
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
dump                 1 all custom 1000 ${sname}.heat.lammpstrj id type xu yu zu vx vy vz
fix                  4 all nvt temp 1.0 ${rtemp} 100.0
run                  10000
unfix                4
undump               1
                     
print                .
print                ================================================
print                "NPT dynamics with an isotropic pressure of 1atm."
print                ================================================
print                .
                     
fix                  2 all npt temp ${rtemp} ${rtemp} 100.0 iso 1.0 1.0 2000.0
dump                 1 all custom 5000 ${sname}.${rtemp}K.npt.lammpstrj id type xu yu zu vx vy vz
variable             latx equal lx
variable             laty equal ly
variable             latz equal lz
fix                  lxavg all ave/time 1 250000 250000 v_latx
fix                  lyavg all ave/time 1 250000 250000 v_laty
fix                  lzavg all ave/time 1 250000 250000 v_latz
run                  1000000 # run for 15 ns
variable             xavg equal f_lxavg
variable             yavg equal f_lyavg
variable             zavg equal f_lzavg
undump               1
unfix                2
print                "current cell: ${latx} ${laty} ${latz} cell avgs: ${xavg} ${yavg} ${zavg}"
print                "deforming cell"
fix                  2 all nvt temp ${rtemp} ${rtemp} 100.0 nreset 10000
dump                 1 all custom 5000 ${sname}.${rtemp}K.deform.lammpstrj id type xu yu zu vx vy vz
fix                  1 all deform 100 x final 0 ${xavg} y final 0 ${yavg} z final 0 ${zavg} units box
undump               1
unfix                lxavg
unfix                lyavg
unfix                lzavg
run                  100000
unfix                1
unfix                2
fix                  2 all nvt temp ${rtemp} ${rtemp} 100.0 nreset 10000
dump                 1 all custom 5000 ${sname}.${rtemp}K.nvt.lammpstrj id type xu yu zu vx vy vz
run                  500000
undump               1
unfix                2
reset_timestep       1000000
                     
print                .
print                ================================================
print                "NVT production dynamics "
print                ================================================
print                .
                     
fix                  2 all nvt temp ${rtemp} ${rtemp} 100.0 tloop 10 ploop 10
restart              50000 ${sname}.${rtemp}K.*.restart
dump                 1 all custom 1000 ${sname}.${rtemp}K.prod.lammpstrj id type xu yu zu vx vy vz
run                  5000000 # run for 15 ns
unfix                2
undump               1
__END_TEMPLATE_EQUIL__

#Tcl

__TEMPLATE_TCL__
if {$argc < 2} {
    puts "Usage: ./script.tcl rtemp mol2"
    exit 1
}
set rtemp [lindex $argv 0]
set prefix [lindex $argv 1]

puts "Basename without .mol2: $arg2"

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
