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
