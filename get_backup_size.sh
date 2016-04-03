#!/bin/sh
# This script calculates the size of each "backup." folder.
# The size of the first (oldest) folder is calculated completely.
# the following folders are calculated without included hardlinks.
# This way you get the difference in size of each backup to the previous one


DIR="$1"

cd "$DIR"

#ls -lAtr $DIR | grep " backup." | awk '{printf $9." "}' | cut -d / -f 1
FOLDERS=`ls -lAtr $DIR | grep " backup." | awk '{printf $9." "}' | cut -d / -f 1`

if [ "$FOLDERS" = "" ]
then
  echo "No backup-folders found! Wrong drirectory?"
else
  #ls -lAtr | grep " backup." | awk '{printf $9." "}' | cut -d / -f 1 | du -hcl --max-depth=0
  du -hc --max-depth=0 $FOLDERS
fi

exit 0


