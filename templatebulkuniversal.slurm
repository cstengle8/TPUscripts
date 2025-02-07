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


~/ATLAS-toolkit/scripts/convertLammpsTrj.pl -b {input}typed.bgf -l {input}equil.300K.prod.lammpstrj -t $(grep "TIMESTEP" {input}equil.300K.prod.lammpstrj | wc -l) -m 1 -o bgf -s {input}post.bgf

sed -i '/^CRYSTX/d' {input}post.bgf

~/ATLAS-toolkit/scripts/addBoxToBGF.pl {input}post.bgf {input}primer.bgf

~/ATLAS-toolkit/scripts/replicate.pl -b {input}primer.bgf -d '2 2 2' -s replicated{input}.bgf

~/ATLAS-toolkit/scripts/createLammpsInput.pl -b replicated{input}.bgf -f "~/ff/DREIDING2.21.ff" -s bulk{input}

cp {input}template.bulk in.bulk{input}

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
$PARALLEL $LMP -in ${lmp_equil_file} -log ${lmp_log_file} -var rtemp {rtemp3} -var press 1 -var ctemp {ctemp}
