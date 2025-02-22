Set of scripts designed to take an input mol2 file (TPU chain), equilibrate a single chain, replicate into a 2 x 2 x 2 bulk structure, engage in further equilibration, along with a tensile deformation simulation. 

This script should work well with any mol2 file, not just a TPU chain. The replication parameters are tunable in the script, basic simulation parameters will be prompted when running prepareTPUbatch.sh. One needs access to the ATLAS-toolkit suite of scripts, slurm job submit system, lammps, and vmd. 

Simply run prepareTPUbatch.sh in the same directory with all of the template files, and batch submission files for single chain, bulk, and deformation will be created; all with embedded lammps input templates. 

The lammps simulation parameters (pair_style, etc.) are hard coded into the templates, changing them could result in simulations to break, run times to last long, etc. 
