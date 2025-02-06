if {$argc < 1} {
    puts "Usage: ./script.tcl argument"
    exit 1
}
set arg [lindex $argv 0]

package require topotools

mol new TPU4.mol2 type mol2 waitfor all

mol addfile "TPU4.${arg}.npt.lammpstrj" type lammpstrj waitfor all

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
