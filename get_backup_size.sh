#!/bin/sh
# This script calculates the size of each "backup." folder.
# The size of the first (oldest) folder is calculated completely.
# the following folders are calculated without included hardlinks.
# This way you get the difference in size of each backup to the previous one


DIR="$1"

cd "$DIR"

echo "du -hc -d 0 "`ls -trx | tr '\n' ' ' | tr 'log' ' '` | sh

exit 0
