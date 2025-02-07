if {$argc < 2} {
    puts "Usage: ./script.tcl rtemp mol2"
    exit 1
}
set arg [lindex $argv 0]
set arg2 [string trim [exec basename $inputFilename --suffix .mol2]
puts "Input filename: $inputFilename"
puts "Basename without .mol2: $arg2"

package require topotools

mol new ${arg2}.mol2 type mol2 waitfor all

mol addfile "${arg2}.${arg}.npt.lammpstrj" type lammpstrj waitfor all

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
