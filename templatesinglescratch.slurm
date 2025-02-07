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

cp {input}template.minimize in.{input}

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

vmd -dispdev text -e template.tcl -eofexit -args "$rtemp" "{input}"

module load gcc/10.2.0
module load openbabel/3.0.0

obabel -imol2 {input}vmd.mol2 -obgf -O{input}min.bgf

~/ATLAS-toolkit/scripts/autoType.pl -i {input}min.bgf -f ~/ATLAS-toolkit/ff/DREIDING2.21.ff -t bgf -s {input}typed.bgf

sed -i '/^CRYSTX/d' {input}typed.bgf

~/ATLAS-toolkit/scripts/addBoxToBGF.pl {input}typed.bgf {input}box.bgf

~/ATLAS-toolkit/scripts/createLammpsInput.pl -b {input}box.bgf -f ~/ATLAS-toolkit/ff/DREIDING2.21.ff -s {input}equil

cp {input}template.equil in.{input}equil

module load gcc/9.2.0
module load netlib-lapack
# File names
lmp_equil_file=in.{input}equil
lmp_data_file=data.{input}equil
lmp_log_file={input}equil.log
LMP="/home/rramji/codes/LAMMPS/speed_lammps/build_custom/lmp_rob -var rtemp {rtemp2} -var press 1"

# Echo job details
echo "LAMMPS dynamics of {input}equil at {rtemp2}K"

# Run LAMMPS
$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var rtemp {rtemp2} -var press 1
