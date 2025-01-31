# Script to update mol2 coordinates from last frame of trajectory
package require topotools

# Load the mol2 file first to get topology
mol new TPU4.mol2 type mol2 waitfor all

# Load the trajectory file
mol addfile TPU4.300K.npt.lammpstrj type lammpstrj waitfor all

# Get the number of frames
set nf [molinfo top get numframes]
# Go to last frame
animate goto $nf

# Get atom coordinates from last frame and update
set sel [atomselect top all frame last]
$sel writemol2 TPU4vmd.mol2
$sel delete

# Exit VMD
quit
