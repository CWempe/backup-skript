#!/bin/bash
# Dieses Script zeigt die Groesse der inkrementellen Backups eines Hosts an
# Dazu werden die rsync.log.*-Dateien ausgewertet.
#
# Per Default wird die Groesse aus "vorhandenen" und "übertragenen" Bytes gestacked angezeigt
# Man kann "--no-stacked" angeben, damit die Balken untereinander angezeigt werden
# Man kann "--diff" angeben, damit nur die Differenz zur vorigen Backup angezeigt wird
# Ein Host kann ausgewählt oder via "--host" direkt angegeben werden.


WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Ein " um das Syntaxhighlighting wieder zu korrigieren
LCONFIG="$WORKDIR/conf/remote-system-backup.conf"

# Pruefen ob lokale Config vorhanden ist
if [ ! -f "$LCONFIG" ]
    then
        MESSAGE="Nicht existierende Config-Datei fuer das lokale System angegeben!\n\nAngegeben wurde: $LCONFIG\n\nSkript wurde NICHT ausgefuehrt!"
        echo "$MESSAGE"
        exit 3
fi
# Konfiguration fuer das lokale System importieren
source "$LCONFIG"


### Parameter auswerten
diff=0
termgraph_arg_stacked="--stacked"
no_graph=0
HOST=""
# Farbe der Balken
COLOR1="blue"
COLOR2="red"

for arg in "$@"; do
  case "$arg" in
    --diff)
      diff=1
      termgraph_arg_stacked=""
      ;;
    --no-stacked)
      termgraph_arg_stacked=""
      ;;
    --no-graph)
      no_graph=1
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    *)
      ;;
  esac
done


### Hosts zur Auswahl anbieten
if [[ ${HOST} == "" ]]; then
  # Nur Verzeichnisse auflisten
  folders=()
  while IFS= read -r -d '' dir; do
      folders+=("$(basename "$dir")")
  done < <(find "${GPATH}" -mindepth 1 -maxdepth 1 -type d -print0)

  # Prüfen, ob Ordner vorhanden sind
  if [ ${#folders[@]} -eq 0 ]; then
      echo "Keine Unterordner im Verzeichnis gefunden."
      exit 1
  fi

  # Ordner zur Auswahl anzeigen
  echo "Bitte wählen Sie einen Ordner:"
  for i in "${!folders[@]}"; do
      printf "[%d] %s\\n" "$i" "${folders[$i]}"
  done

  # Benutzereingabe
  read -p "Geben Sie die Nummer des Ordners ein: " choice

  # Eingabe prüfen
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -ge "${#folders[@]}" ]; then
      echo "Ungültige Auswahl."
      exit 1
  fi

  # Gewählten Ordner anzeigen
  echo ""
  echo "Sie haben gewählt: ${folders[$choice]}"

  HOST="${folders[$choice]}"
fi

DIR="${GPATH}/${HOST}/log"


#termgraph_args="$2"
termgraph_arg_width="--width $(( $(tput cols) - 35 ))"


### Abhaengigkeiten ueberpruefen

if [ ! -d "$DIR" ]; then
    echo "Fehler: Verzeichnis ${DIR} existiert nicht!" >&2
    exit 1
else
    cd "$DIR"
fi

if ! command -v termgraph &> /dev/null; then
    echo "Fehler: termgraph ist nicht installiert. Bitte mit 'python3 -m pip install termgraph' installieren." >&2
    echo "Quelle: https://github.com/EduardKononov/termgraph" >&2
    exit 1
fi

# Prüfen, ob awk BusyBox ist
if awk '' 2>&1 | grep -q "BusyBox"; then
    echo "awk ist BusyBox-Version"

    # Prüfen, ob gawk verfügbar ist
    if command -v gawk >/dev/null 2>&1; then
        # GNU awk ist installiert – verwende gawk
        AWK=gawk
    else
        echo "gawk ist NICHT installiert. Bitte mit zum Beispiel 'opkg install gawk' installieren."
        exit 1
    fi
else
    # awk ist GNU awk oder kompatibel
    AWK=awk
fi

### Groessenordnung ermitteln
if [ "$diff" -eq 0 ]; then
  line=$(grep "Total file size" rsync.log.0)
  # Extrahiere den Wert und die Einheit (z.B. "3.45G")
  value_with_unit=$(echo "$line" | awk '{print $(NF-1)}')
  # ' für Syntaxhighlighting für mcedit
else
  line=$(grep "Total bytes received" rsync.log.0)
  # Extrahiere den Wert und die Einheit (z.B. "3.45G")
  value_with_unit=$(echo "$line" | awk '{print $(NF)}')
  # ' für Syntaxhighlighting für mcedit
fi


# Einheit extrahieren (letzter Buchstabe)
unit=$(echo "$value_with_unit" | grep -o '[KMGTP]$')
# ' für Syntaxhighlighting für mcedit

# Faktor bestimmen
case "$unit" in
    T) factor=1099511627776 ;;  # 1024^4
    G) factor=1073741824 ;;     # 1024^3
    M) factor=1048576 ;;        # 1024^2
    K) factor=1024 ;;
    "") factor=1 ;;             # falls keine Einheit
    *) echo "Unbekannte Einheit: $unit" >&2; exit 1 ;;
esac


### Graf erzeugen
# Titel darf keine Leerzeichen enthalten, weil dieses Script das nicht unterstuetzt
termgraph_title="Host:${HOST}"

# Create termgraph-command
termgraph_cmd=(termgraph)
termgraph_cmd+=(${termgraph_arg_width})
termgraph_cmd+=(${termgraph_arg_stacked})
termgraph_cmd+=(--suffix)
termgraph_cmd+=(${unit}B)
termgraph_cmd+=(--title)
termgraph_cmd+=(${termgraph_title})
if [[ $diff -eq 0 ]]; then
  termgraph_cmd+=(--color {${COLOR1},${COLOR2}})
else
  # Definiere zweite Farbe als primär, wenn nur die Differenzgroesse ausgegeben wird
  termgraph_cmd+=(--color ${COLOR2})
fi


### DEBUG
#echo ""
#echo "DIR: $DIR"
#echo "AWK: $AWK"
#echo "COLOR1: $COLOR1"
#echo "COLOR2: $COLOR2"
#echo "diff: $diff"
#echo "factor: $factor"
#echo "termgraph_arg_width: $termgraph_arg_width"
#echo "termgraph_arg_stacked: $termgraph_arg_stacked"
#echo "termgraph_cmd; ${termgraph_cmd[@]}"
#echo ""


# gawk statt awk, damit es auch auf Systemen mit BusyBox läuft
grep -e "Total file size" -e "Total bytes received" rsync.log.* | \
  ${AWK} -v factor="$factor" -v diff=$diff '
    function human2bytes(value_with_unit) {
        gsub(",", ".", value_with_unit)          # Komma durch Punkt ersetzen
        match(value_with_unit, /([0-9.]+)([KMGT]?)/, m)
        val = m[1]
        unit = m[2]
        # convert every number to byte
        if (unit == "T") return val * 1024 * 1024 * 1024 * 1024
        if (unit == "G") return val * 1024 * 1024 * 1024
        if (unit == "M") return val * 1024 * 1024
        if (unit == "K") return val * 1024
        return val
    }
    {
        split($1, parts, ":")
        file = parts[1]

        if ($0 ~ /Total file size:/) {
            value = $(NF-1)  # vorletztes Feld, da "bytes" am Ende steht
            size[file] = human2bytes(value)
        } else if ($0 ~ /Total bytes received:/) {
            value = $NF  # letztes Feld, da kein "bytes" am Ende steht
            received[file] = human2bytes(value)
        }
    }
    END {
        for (f in size) {
            if (received[f] > 0) {
                s = size[f] / factor
                r = received[f] / factor
                d = s - r
                if (diff == 1) {
                    # ohne erste Spalte ausgeben (nur Differenz zur letzten Sicherung)
                    printf "%s,%.2f\n", f, r
                } else {
                    # mit erster Spalte (Dateiname)
                    printf "%s,%.2f,%.2f\n", f, d, r
                }
            }
        }
    }
  '  | \
  sort -V | \
  ${termgraph_cmd[@]}
  #termgraph ${termgraph_arg_width} ${termgraph_arg_stacked} --title "${termgraph_title}" --suffix ${unit}B --color {$COLOR1,$COLOR2}


