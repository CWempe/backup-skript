#!/bin/bash

WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Ein " um das Syntaxhighlighting wieder zu korrigieren
LCONFIG="${WORKDIR}/conf/remote-system-backup.conf"

# Pruefen ob lokale Config vorhanden ist
if [ ! -f "$LCONFIG" ]
    then
        MESSAGE="Nicht existierende Config-Datei fuer das lokale System angegeben!\n\nAngegeben wurde: $LCONFIG\n\nSkript wurde NICHT ausgefuehrt!"
        echo -e "$MESSAGE\n"
        exit 3
fi
# Konfiguration fuer das lokale System importieren
source "$LCONFIG"



HOST="$1"
#DIR="$1"
BACKUPDIR="${GPATH}/${HOST}"
EMPTYDIR="/tmp/empty_dir"

echo ""
echo "### Zeit: $(date +%F--%H-%M-%S)"

# erstelle leeren Ordner
mkdir "${EMPTYDIR}"
echo "${EMPTYDIR}"

for i in $(seq 29 -1 10); do
  echo ""
  echo "### $(date +%F--%H-%M-%S): ${BACKUPDIR}/backup.$i/:"
  time rsync -a --delete "${EMPTYDIR}/" "${BACKUPDIR}/backup.$i/"
  rm -r "${BACKUPDIR}/backup.$i/"
done

echo ""
echo "### Zeit: $(date +%F--%H-%M-%S)"

echo ""
echo "# Lösche leeres Temp-Verzeichnis"
rm -r "${EMPTYDIR}"
