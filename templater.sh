#!/bin/bash
output="`basename --suffix .mol2 $1`singlechainscript.sh"
sed "s/{input}/$(basename --suffix=.mol2 "$1")/g" templatesingle.sh > "$output"
output2="`basename --suffix .mol2 $1`bulkscript.sh"
sed "s/{input}/$(basename --suffix=.mol2 "$1")/g" templatebulk.sh > "$output2"
