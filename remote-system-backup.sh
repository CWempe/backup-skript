#!/bin/bash
# ./remote-system-backup.sh (root:root , 700)
#
####################################################################################################
# Backup-Skript zur Sicherung von Systemen auf einen zentralen Backup-Server.
# Das Skript erfordert den Austausch von SSH-Keys zwischen Server und dem
# zu sichernden System.
# Das Skript wird per cron-Job (naechtlich) gestartet.
# Fuer Testszenarien steht ein Debug-Modus mit erweiterter Ausgabe zur Verfuegung
# Der RSYNC wird nicht ausgefuehrt (Befehlsausgabe per echo)
# Aufrufbar durch: ./remote-system-backup.sh -d "configfile"
#
####################################################################################################

# Auflistung aller verwendeten Variablen mit Erlaeuterung:
#
# DAY           = Abkuerzung des aktuellen Wochentagnamens
# RSYNC         = Pfad zum rsync-Befehl
# SSH           = Pfad zum ssh-Befehl
# SENDMAIL      = Pfad zum sendmail-Befehl
# FIND          = Pfad zum find-Befehl
# WC            = Pfad zum wc-Befehl
# FROMNAME      = vollstaendiger Name des Absenders, der im Mailclient angezeigt wird
# FROMMAIL      = Absenderadresse
# FROM          = Kombination aus den beiden obenren Variablen im Syntax fuer den Mailheader
# SUBJECTMAIN   = Betreff der Mails
# SUBJECTSUC    = Betreff bei erfolgreichen Meldungen
# SUBJECTERR    = Betreff bei Fehlermeldungen
# SYSTEM        = Gibt das System des Servers an, um spezielle Pfade zu beruecksichtigen
# ADMINMAIL     = Mailadresse, an die Fehlernachrichten geschickt werden
# MAIL          = Mailadresse an die STAT oder Informationen zum Ablauf bei erfolgreichem oder
#                 nicht erfolgreichem Durchlauf geschickt werden
# PFADE         = Variable fuer die Dateipfade aus RPATH
# BACKUPCOUNTER = Variable fuer Laufzahlen
# STATCOUNTER   = Anzahl der Stat-Dateien im LPATH.
# LOGCOUNTER    = Anzahl der Log-Dateien im LPATH.
# DEBUG         = gibt an ob der Debug-Modus durchgefuehrt werden soll
# RCONFIG       = Pfad zur config-Datei fuer das zu sichernde System
# LCONFIG       = Pfad zur config-Datei für das lokale System
# ANZAHLBACKUPS = Anzahl von Backups die aufgehoben werden sollen
# LPATH         = Pfad zum Backup-Ordner auf dem Backup-Server
# RPATH         = Pfad zum Verzeichnis das gesichert werden soll
# RHOST         = Netzwerkname des PC`s von dem Daten gesichert werden sollen
# RUSER         = User des PC`s von dem Daten gesichert werden sollen (optional; default 'root')
# STAT          = Pfad zur Statistik-LOG-Datei von RSYNC fuer den Benutzer bei korrektem Durchlauf
# ADMINLOG      = Pfad zu den Fehlerausgaben die an ADMINMAIL geschickt werden
# LOG           = Pfad zu den durchgefuehrten rsync Kommandos
# STIME         = Startzeit des Backup-Vorgangs fuer Ausgabe
# CTIME         = Endezwit des Kopier-Vorgangs fuer Ausgabe
# ETIME         = Endezeit des Backup-Vorgangs fuer Ausgabe
# 


# Setzen der temporaeren Parameter
####################################################################################################

DAY=`date +%F--%H-%M-%S`
RSYNC="/usr/bin/rsync"
SSH="/usr/bin/ssh"
SENDMAIL="/usr/sbin/sendmail"
FIND="/usr/bin/find"
WC="/usr/bin/wc"
WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Ein " um das Syntaxhighlighting wieder zu korrigieren
LCONFIG="$WORKDIR/conf/remote-system-backup.conf"


STIME=`date +%F--%H-%M-%S`

# Pruefen ob mehr als eine Konfigdatei (mehr als ein Parameter) uebergeben wurde
# Ist keine oder mehr als eine Konfigdatei uebergeben worden - Abbruch.
# Kontrolliere ob zwei Parameter uebergeben wurden, wobei der erste ( -d) die Debug-Option
# aktiviert und der zweite den Pfad zur Config-Datei darstellt.
# Wenn ja:  DEBUG=yes ansonsten DEBUG=no
# Im weiteren wird ggf. eine Debug-Ausgabe zu den einzelnen Schritten hinzugefuegt
####################################################################################################

# Pruefen ob lokale Config vorhanden ist
if [ ! -f "$LCONFIG" ]
    then
        MESSAGE="Nicht existierende Config-Datei fuer das lokale System angegeben!\n\nAngegeben wurde: $LCONFIG\n\nSkript wurde NICHT ausgefuehrt!"
        echo -e "$MESSAGE\n"
        exit 3
fi
# Konfiguration fuer das lokale System importieren
source "$LCONFIG"


if [ "$#" = 0 ]
    then
	echo "Es wurde keine Config-Datei angegeben!"
	echo " "
	echo "SYNTAX: ./remote-system-backup.sh [-d] config-datei"
	echo "  [-d]         - Optional, Aktivierung des Debug-Mode (nur Anzeige der Befehle)"
	echo "  config-datei - Pfad zur Konfigurationsdatei"
	echo " "
	echo "Informationen zum Skript siehe remote-system-backup.hlp."
	echo " "
	echo "EXIT!"
	exit 3

elif [ "$#" = 1 ]
    then
	RCONFIG=$1

	if [ ! -f "$RCONFIG" ]
	    then
                SUBJECT="$SUBJECTERR"
                MESSAGE="Nicht existierende Config-Datei angegeben!\n\nAngegeben wurde: $RCONFIG\n\nSkript wurde NICHT ausgefuehrt!"
                echo -e "$MESSAGE\n"
                echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
                exit 3
	fi

elif [ "$#" = 2 ]
    then

	if [ "$1" = "-d" ]
	    then
		echo -e "Debug-Modus aktiviert!\n"
		DEBUG=yes
		RCONFIG=$2

		if [ ! -f "$RCONFIG" ]
		    then
			echo -e "Nicht existierende Config-Datei \"($RCONFIG)\" angegeben!\nSkript wurde NICHT ausgefuehrt!\n"
			exit 3
		fi

	    else
                SUBJECT="$SUBJECTERR"
                MESSAGE="Falsche Parameter wurden uebergeben!\n\nSkript wurde NICHT ausgefuehrt!"
                echo -e "$MESSAGE"
                echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
                exit 3
	fi


elif [ "$#" -gt 2 ]
    then
        SUBJECT="$SUBJECTERR"
        MESSAGE="Zu viele Parameter wurden uebergeben!\n\nSkript wurde NICHT ausgefuehrt!"
        echo -e "$MESSAGE"
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
	exit 3
fi



# Anpassen der Pfade fuer spezielle Systeme
###################################################################################################
case "$SYSTEM" in
    QNAP)
        if [ $DEBUG == "yes" ] ; then echo "Verwende Pfade fuer QNAP."; fi
        RSYNC="/usr/bin/rsync"
        SSH="/usr/bin/ssh"
        SENDMAIL="/usr/sbin/sendmail"
        BUSYBOX="/opt/bin/busybox"
        if [ ! -f "$BUSYBOX" ] ; then
            MESSAGE="busybox wurde nicht gefunden.\n\nBitte Pfad ueberpruefen ($BUSYBOX)\noder ggf. busybox ueber Optware/IPIKG nachinstallieren!"
            if [ $DEBUG == "yes" ] ; then
                echo -e "$MESSAGE"
            else
                SUBJECT="$SUBJECTERR"
                echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
            fi
            exit 5
        fi
        FIND="$BUSYBOX find"
        WC="$BUSYBOX wc"
        ;;
    openELEC)
        if [ $DEBUG == "yes" ] ; then echo "Verwende Pfade fuer openELEC."; fi
        RSYNC="/storage/.kodi/addons/network.backup.rsync/bin/rsync"
        ;;
    Raspbian)
#        if [ $DEBUG == "yes" ] ; then echo "Verwende Pfade fuer Raspbian."; fi
# to do
        ;;
    enigma2)
#        if [ $DEBUG == "yes" ] ; then echo "Verwende Pfade fuer Raspbian."; fi
# to do
        ;;
    *)
        if [ $DEBUG == "yes" ] ; then echo "Verwende Standardpfade."; fi
esac




# Variablen aus der conf-Datei einfuegen
####################################################################################################

source "$RCONFIG"


# Kontrollieren ob die Variablen der conf-Datei korrekt gesetzt wurden sonst erfolgt eine
# Benachrichtigung per Mail und das Backup wird nicht durchgefuehrt
####################################################################################################

if [ "1" != "$SSHTYPE" -a "2" != "$SSHTYPE"   ] ; then
    MESSAGE="Falsche oder keine SSH-Typ-Angabe!\n\nSkript wurde nicht ausgefuehrt!"
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    else
        SUBJECT="$SUBJECTERR"
        echo -e "$MESSAGE"
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
    fi
    exit 5
fi

    if [ "1" == "$SSHTYPE" ] ; then SSH="/usr/bin/ssh -1"
        if [ $DEBUG == "yes" ] ; then echo "SSH-Typ \"1\" gewaehlt!" ; fi
    fi

    if [ "2" == "$SSHTYPE" ] ; then SSH="/usr/bin/ssh -2" 
        if [ $DEBUG == "yes" ] ; then echo "SSH-Typ \"2\" gewaehlt!" ; fi
    fi

####################################################################################################

if [ -z "$BWLIMIT" ] ; then
    MESSAGE="Kein Bandbreitenlimit angegeben!"
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    fi
    BWLIMITCMD=""
else
    if [ $BWLIMIT -gt 0 ]
    then
        MESSAGE="Bandbreitenlimit gesetzt auf $BWLIMIT"
        if [ $DEBUG == "yes" ] ; then
            echo -e "$MESSAGE"
        fi
        BWLIMITCMD="--bwlimit=$BWLIMIT"
    else
        MESSAGE="Bandbreitenlimit ungueltig: $BWLIMIT"
        if [ $DEBUG == "yes" ] ; then
            echo -e "$MESSAGE"
        fi
        exit 5
    fi
fi

####################################################################################################

if [ -z "$MAIL" ] ; then
    MESSAGE="Falsche MAIL-Angabe! Skript wurde nicht ausgefuehrt!"
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    else
        SUBJECT="$SUBJECTERR"
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
    fi
    exit 5
fi

####################################################################################################
# Pruefe ob $RRSYNC gesetzt ist, sonst RRSYNC als Standardpfad nehmen

if [ ! -z "$RRSYNC" ] ; then
    if [ $DEBUG == "yes" ] ; then
	echo "RRSYNC ist gesetzt. Verwende $RRSYNC als Pfad fuer das Remotesystem."
    fi
    RSYNCPATH="--rsync-path=$RRSYNC"
  else
    if [ $DEBUG == "yes" ] ; then
	    echo -e "RRSYNC ist nicht gesetzt. Verwende den Standardpfad.\n"
    fi
    RSYNCPATH=""
fi

####################################################################################################

if [ -z "$RHOST" ] ; then
    MESSAGE="Falsche RHOST-Angabe! Skript wurde nicht ausgefuehrt!"
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    else
        SUBJECT="$SUBJECTERR"
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
    fi
    exit 5
fi

# Betreff der Mails erneut setzen, da jetzt RHOST definiert ist
SUBJECTSUC="[BACKUP-Skript] ✔ ($RHOST) erfolgreich"
SUBJECTERR="[BACKUP-Skript] ✘ ($RHOST) Fehler"



####################################################################################################

if [ -z "$RIP" ] ; then
    if [ $DEBUG == "yes" ] ; then
        echo "Kein RIP angegeben! Verwende $RHOST."
    fi
    RIP="$RHOST"
fi


####################################################################################################

if [ -z "${HWADDR}" ] ; then
    if [ $DEBUG == "yes" ] ; then
        echo "Keine MAC-Adresse angegeben."
    fi
    WOL="no"
else
    if [[ "$HWADDR" =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]] ; then
        if [ $DEBUG == "yes" ] ; then
                echo "HWADDR ist korrekt! $HWADDR."
        fi
        WOL="yes"
    else
        MESSAGE="Ungueltige MAC-Adresse angegeben: ${HWADDR}"
        if [ $DEBUG == "yes" ] ; then
            echo -e "$MESSAGE"
        else
            SUBJECT="$SUBJECTERR"
            echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
            echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
        fi
        exit 5
    fi
fi

####################################################################################################

if [ -z "$RUSER" ] ; then
    if [ $DEBUG == "yes" ] ; then
	    echo "Kein RUSER angegeben! Verwende 'root'."
    fi
    RUSER="root"
fi

####################################################################################################

if [ -z "$ANZAHLBACKUPS" ] || [ "$ANZAHLBACKUPS" -le 0 ] ; then
    MESSAGE="Falsche ANZAHLBACKUPCOUNTS-Angabe! Skript wurde nicht ausgefuehrt!"
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    else
        SUBJECT="$SUBJECTERR"
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
    fi
    exit 5
fi


# Pruefe ob LPATH gesetzt ist. Wenn nicht erstelle den Pfad aus GPATH+RHOST
####################################################################################################

if [ -z "$LPATH" ] ; then
    if [ -z "$GPATH" ] ; then
        if [ $DEBUG == "yes" ] ; then
            MESSAGE="Auch GPATH-Angabe falsch! Skript wurde nicht ausgefuehrt!"
        else
            SUBJECT="$SUBJECTERR"
            echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
            echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
        fi
        exit 5
    else
        MESSAGE="Keine LPATH-Angabe! Verwende $GPATH/$RHOST."
        if [ $DEBUG == "yes" ] ; then
            echo -e "$MESSAGE"
        fi
        LPATH="$GPATH/$RHOST"
    fi
fi

####################################################################################################

if [ -z "$RPATH" ] ; then
    MESSAGE="Falsche RPATH-Angabe! Skript wurde nicht ausgefuehrt!"
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    else
        SUBJECT="$SUBJECTERR"
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
    fi
    exit 5
fi


####################################################################################################

if [ -z "$LOG" ] ; then
    MESSAGE="Keine LOG-Angabe! Verwende $LPATH/log."
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    fi
    LOG="$LPATH/log"
fi


####################################################################################################

if [ -z "$STAT" ] ; then
    MESSAGE="Keine STAT-Angabe! Verwende $LPATH/log."
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    fi
    STAT="$LPATH/log"
fi

####################################################################################################

if [ -z "$ADMINLOG" ] ; then
    MESSAGE="Keine ADMINLOG-Angabe! Verwende $LOG/admin.log."
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    fi
    ADMINLOG="$LOG/admin.log"
fi


# Kontrollieren ob der Benutzer "root" ist. Wenn nicht: Skript abbrechen, Benachrichtigung per Mail
####################################################################################################

if [ $(/usr/bin/id -u) != 0 ]; then
    if [  $(/usr/bin/id -u) == 1000 ] && [ "$SYSTEM" == "OSMC" ]; then
        MESSAGE="Keine root-Rechte. Aber unter OSMC kann der User osmc genutzt werden!"
        if [ $DEBUG == "yes" ] ; then
            echo -e "$MESSAGE"
        fi
    else
        MESSAGE="Keine root-Rechte. Skript wird nicht ausgefuehrt!"
        if [ $DEBUG == "yes" ] ; then
            echo -e "$MESSAGE"
        else
            SUBJECT="$SUBJECTERR"
            echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
            echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
        fi
        exit 5
    fi
fi


# Server ggf. per Wake-on-LAN aufwecken
####################################################################################################

if [ "${WOL}" == "yes" ] ; then
    if [ $DEBUG == "yes" ] ; then
        echo "Server per Wake-on-LAN aufwecken und einen Moment warten."
    fi
    wakeonlan ${HWADDR}
    sleep 60
fi


# Pruefen ob der Server erreichbar ist. Wenn nicht: Skript abbrechen, Benachrichtigung per Mail
####################################################################################################

if [ $DEBUG == "yes" ] ; then
    echo "Pruefe ob Server erreichbar ist."
fi

ping -q -c 2 $RIP > /dev/null
if [ $? -eq 1 -o $? -eq 2 ] ; then
    MESSAGE="$RIP ist nicht erreichbar.\nBackup wird abgebrochen."
    if [ $DEBUG == "yes" ] ; then
        echo -e "$MESSAGE"
    else
        SUBJECT="$SUBJECTERR"
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
    fi
    exit 6
else
    if [ $DEBUG == "yes" ] ; then
        echo -e "$RIP ist erreichbar.\n"
    fi
fi

# Kontrollieren ob der LOG-Pfad existiert, ansonsten mit uebergeordneten Verzeichnissen erstellen.
####################################################################################################

if [ ! -d $LPATH/log ]; then
    if [ $DEBUG == "yes" ] ; then
	echo "LOG-Pfad existiert nicht! Wird angelegt durch:"
	echo -e "mkdir -p $LPATH/log\n"
	mkdir -p $LPATH/log
    else
	mkdir -p $LPATH/log
    fi
fi

####################################################################################################
####################################################################################################


# Backup-Verzeichnis bereinigen und Benutzer informieren
# falls ueberschuessige Backups geloescht werden sollen.
####################################################################################################

if [ $DEBUG == "yes" ] ; then
    echo -e "Backup-Verzeichnis bereinigen...\n"
fi

# BACKUPCOUNTER bekommt die Anzahl der Backup-Ordner im LPATH
# ohne den LOG-Ordner und das letzte Backup zugewiesen
####################################################################################################

BACKUPCOUNTER=$($FIND $LPATH -maxdepth 1 -type d -name "backup.*" | $WC -l)
BACKUPCOUNTER=$(($BACKUPCOUNTER-1))


if [ $(($BACKUPCOUNTER+1)) -gt $ANZAHLBACKUPS ] ; then
    >> $ADMINLOG
    while [ $(($BACKUPCOUNTER+1)) -gt $ANZAHLBACKUPS ]
	do
	    if [ -d $LPATH/backup.$BACKUPCOUNTER ] ; then
		if [ $DEBUG == "yes" ] ; then
		    echo -e "Alten Ordner $LPATH/backup.$BACKUPCOUNTER bis Ordner $LPATH/backup.$ANZAHLBACKUPS loeschen.\nBeende..."
		    exit 7
		else
		    echo "Alter Ordner $LPATH/backup.$BACKUPCOUNTER muss geloescht werden! Skript wurde nicht ausgefuehrt!" >> $ADMINLOG
		fi
	    fi
	    BACKUPCOUNTER=$(($BACKUPCOUNTER-1))
	done
    MESSAGE=`cat $ADMINLOG`
    SUBJECT="$SUBJECTERR"
    echo -e "$MESSAGE"
    echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
    MESSAGE="Skript wurde nicht ausgefuehrt!"
    echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
    exit 7
fi


if [ $DEBUG == "yes" ] ; then
    echo -e "Backup-Verzeichnis kann bereinigt werden...\n"
fi

# Backups umsortieren (Laufzahlincrement)
####################################################################################################

    if [ -d $LPATH/backup.$(($ANZAHLBACKUPS-1)) ] ; then
	if [ $DEBUG == "yes" ] ; then
	    echo "Aeltestes Backup wird geloescht durch:"
	    echo -e "rm -rf $LPATH/backup.$(($ANZAHLBACKUPS-1))\n"
	    else
		rm -rf $LPATH/backup.$(($ANZAHLBACKUPS-1))
	fi
    fi

    BACKUPCOUNTER=$(($ANZAHLBACKUPS-2))

    if [ $DEBUG == "yes" ] ; then
	echo -e "Restliche Backups werden umsortiert durch:\n"
    fi

    while [ $BACKUPCOUNTER -ge 0 ]
	do
	    if [ -d $LPATH/backup.$BACKUPCOUNTER ] ; then
		if [ $DEBUG == "yes" ] ; then
		    echo "mv $LPATH/backup.$BACKUPCOUNTER $LPATH/backup.$(($BACKUPCOUNTER+1))"
		    else
			mv $LPATH/backup.$BACKUPCOUNTER $LPATH/backup.$(($BACKUPCOUNTER+1))
		fi
	    fi
	    BACKUPCOUNTER=$(($BACKUPCOUNTER-1))
	done

if [ $DEBUG == "yes" ] ; then
    echo -e "\nErhoehung der Laufzahl der Backups durchgefuehrt!\n"
fi

# Hard-Links erstellen
####################################################################################################

if [ -d $LPATH/backup.1 ] ; then
    if [ $DEBUG == "yes" ] ; then
	    echo "Hard-Link des aktuellesten Backups wird angelegt durch:"
	    echo -e "cp -al $LPATH/backup.1/. $LPATH/backup.0 >/dev/null 2>&1 \n"
	else
	    cp -al $LPATH/backup.1/. $LPATH/backup.0 >/dev/null 2>&1
    fi
fi

CTIME=`date +%F--%H-%M-%S`


# Log- und Stat-Verzeichnis bereinigen und Benutzer informieren falls ueberschuessige Log- und
# Stat-Dateien geloescht werden sollen.
####################################################################################################

if [ $DEBUG == "yes" ] ; then
    echo -e "Log-Verzeichnis bereinigen...\n"
fi


# LOGCOUNTER bekommt die Anzahl der Log-, STATCOUNTER die Anzahl der Stat-Dateien im LPATH.
####################################################################################################

LOGCOUNTER=$($FIND $LOG -maxdepth 1 -type f -name "rsync.log.*" | $WC -l)

STATCOUNTER=$($FIND $STAT -maxdepth 1 -type f -name "rsync.stat.*" | $WC -l)

if ([ $LOGCOUNTER -gt $ANZAHLBACKUPS ] || [ $STATCOUNTER -gt $ANZAHLBACKUPS ]) ; then

    if [ $LOGCOUNTER -gt $ANZAHLBACKUPS ] ; then
	> $ADMINLOG
        while [ $LOGCOUNTER -gt $ANZAHLBACKUPS ]
	    do
		if [ -e $LOG/rsync.log.$(($LOGCOUNTER-1)) ] ; then
		    if [ $DEBUG == "yes" ] ; then
			echo -e "Alte Dateien $LOG/rsync.log.$(($LOGCOUNTER-1)) bis Datei $LOG/rsync.log.$ANZAHLBACKUPS loeschen.\nBeende..."
			exit 7
			else
			    echo "Alte Datei $LOG/rsync.log.$(($LOGCOUNTER-1)) muss geloescht werden! Skript wurde nicht ausgefuehrt!" >> $ADMINLOG
		    fi
		fi
		LOGCOUNTER=$(($LOGCOUNTER-1))
	    done
    fi

    if [ $STATCOUNTER -gt $ANZAHLBACKUPS ] ; then
	> $ADMINLOG
	while [ $STATCOUNTER -gt $ANZAHLBACKUPS ]
	    do
		if [ -e $STAT/rsync.stat.$(($STATCOUNTER-1)) ] ; then
		    if [ $DEBUG == "yes" ] ; then
			echo -e "Alte Dateien $STAT/rsync.stat.$(($STATCOUNTER-1)) bis Datei $STAT/rsync.stat.$ANZAHLBACKUPS loeschen.\nBeende..."
			exit 7
			else
			    echo "Alte Datei $STAT/rsync.stat.$(($STATCOUNTER-1)) muss geloescht werden! Skript wurde nicht ausgefuehrt!" >> $ADMINLOG
		    fi
		fi
		STATCOUNTER=$(($STATCOUNTER-1))
	    done
    fi
    MESSAGE=`cat $ADMINLOG`
    SUBJECT="$SUBJECTERR"
    echo -e "$MESSAGE"
    echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
    MESSAGE="Skript wurde nicht ausgefuehrt!"
    echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
    exit 7
fi

if [ $DEBUG == "yes" ] ; then
    echo -e "Log-Verzeichnis kann bereinigt werden...\n"
fi

# LOG-Dateien umsortieren (Laufzahlincrement)
####################################################################################################

if [ -e $LOG/rsync.log.$(($ANZAHLBACKUPS-1)) ] ; then

    if [ $DEBUG == "yes" ] ; then
	echo "Aelteste Log-Datei wird geloescht durch:"
        echo -e "rm -rf $LOG/rsync.log.$(($ANZAHLBACKUPS-1))\n"
	else
	    rm -rf $LOG/rsync.log.$(($ANZHLBACKUPS-1))
    fi
fi

if [ -e $STAT/rsync.stat.$(($ANZAHLBACKUPS-1)) ] ; then
    if [ $DEBUG == "yes" ] ; then
	echo "Aelteste Stat-Datei wird geloescht durch:"
	echo -e "rm -rf $STAT/rsync.stat.$(($ANZAHLBACKUPS-1))\n"
	else
	rm -rf $STAT/rsync.stat.$(($ANZAHLBACKUPS-1))
    fi
fi

LOGCOUNTER=$($FIND $LOG -maxdepth 1 -type f -name "rsync.log.*" | $WC -l)
STATCOUNTER=$($FIND $STAT -maxdepth 1 -type f -name "rsync.stat.*" | $WC -l)

if [ $LOGCOUNTER -gt 0 ] ; then
    LOGCOUNTER=$(($LOGCOUNTER-1))
fi

if [ $STATCOUNTER -gt 0 ] ; then
    STATCOUNTER=$(($STATCOUNTER-1))
fi

if [ $LOGCOUNTER -ge $(($ANZAHLBACKUPS-1)) ] ; then
    LOGCOUNTER=$(($LOGCOUNTER-1))
fi

if [ $STATCOUNTER -ge $(($ANZAHLBACKUPS-1)) ] ; then
    STATCOUNTER=$(($STATCOUNTER-1))
fi

if [ $DEBUG == "yes" ] ; then
    echo -e "Restliche Log-Dateien werden umsortiert durch:\n"
fi

while [ $LOGCOUNTER -ge 0 ]
    do
	if [ -e $LOG/rsync.log.$LOGCOUNTER ] ; then
	    if [ $DEBUG == "yes" ] ; then    
	    echo "mv $LOG/rsync.log.$LOGCOUNTER $LOG/rsync.log.$(($LOGCOUNTER+1))"
	    else
	    mv $LOG/rsync.log.$LOGCOUNTER $LOG/rsync.log.$(($LOGCOUNTER+1))
	    fi
	fi
    LOGCOUNTER=$(($LOGCOUNTER-1))
done

if [ $DEBUG == "yes" ] ; then
    echo -e "Restliche Stat-Dateien werden umsortiert durch:\n"
fi

while [ $STATCOUNTER -ge 0 ]
    do
	if [ -e $LPATH/backup.$STATCOUNTER ] ; then
	    if [ $DEBUG == "yes" ] ; then    
		echo "mv $STAT/rsync.stat.$STATCOUNTER $STAT/rsync.stat.$(($STATCOUNTER+1))"
		else
		mv $STAT/rsync.stat.$STATCOUNTER $STAT/rsync.stat.$(($STATCOUNTER+1))
	    fi
	fi
    STATCOUNTER=$(($STATCOUNTER-1))
done

if [ $DEBUG == "yes" ] ; then
    echo -e "\nErhoehung der Laufzahl der Log- und Stat-Dateien durchgefuehrt!\n"
fi

####################################################################################################
####################################################################################################

# Beginn des eigentlichen Backups, also durchfuehren des RSYNC
####################################################################################################

if [ $DEBUG == "yes" ] ; then
    echo -e "Backup startet!\n"
fi
if [ -f $LPATH/backup.0 ] ; then
    rm -f $LPATH/backup.0
else
    if [ $DEBUG == "yes" ] ; then
        echo "Keine Datei \"$LPATH/backup.0\" im Pfad"
    fi
fi

# Erstellen der korrekten Systax der Form
# remotehost:/src1 remotehost:/src2 ....
# Alterntiv koennte man auch ein --old-args zum rsync hinzufuegen, dann wuerde die bis 01.09.2022
# funktionierende Version weiterlaufen. Es wurde sich aber fuer diese version entschieden.
# Achtung Eine verarbeitung von Leerzeichen in den angegebenen Pfaden ist technisch durch die
# Uebergabe aus der Shell nicht moeglich.
PFADE=""
PFADE1=""
for PFADE1 in $RPATH ; do
    PFADE="$PFADE $RUSER@$RIP:$PFADE1"
done


# Durchfuehrung RSYNC
if [ $DEBUG == "yes" ] ; then
    echo -e "$RSYNC -R -a -v -P -h $RSYNCATTR --whole-file --delete --delete-excluded --stats -e \"$SSH\" \
    --include-from=$RCONFIG $PFADE "$LPATH/backup.0/" > $LOG/rsync.log.0 2> $LOG/rsync.errorlog.0 \n"
    RSYNCELEVEL=0
else
    $RSYNC -R -a -v -P -h $RSYNCATTR --whole-file --delete --delete-excluded --stats -e "$SSH" \
    --include-from=$RCONFIG $PFADE "$LPATH/backup.0/" > $LOG/rsync.log.0 2> $LOG/rsync.errorlog.0
    RSYNCELEVEL=$?
fi

if [ $DEBUG == "yes" ] ; then
    echo -e "Backup beendet!\n"
fi


# Speichern der letzten 14 Zeilen der Logeintraege in STAT und setzen der Zeitstempel
####################################################################################################

if [ $DEBUG == "yes" ] ; then
    echo -e "Die Uebersicht der Logeintraege wird gesichert, durch:"
    echo -e "tail -14 $LOG/rsync.log.0 > "$STAT/rsync.stat.0" \n "
    else
	tail -14 $LOG/rsync.log.0 > "$STAT/rsync.stat.0"
fi

ETIME=`date +%F--%H-%M-%S`

echo -e "\n---------------------------------------" >> "$STAT/rsync.stat.0"
echo -e "Skript-Startzeit : $STIME"                 >> "$STAT/rsync.stat.0"
echo -e "Copy-Endezeit :    $CTIME"                 >> "$STAT/rsync.stat.0"
echo -e "Skript-Endezeit  : $ETIME"                 >> "$STAT/rsync.stat.0"
echo -e "---------------------------------------"   >> "$STAT/rsync.stat.0"


# Logeintraege versenden
####################################################################################################
MESSAGE="\nFolgende Sicherung wurde durchgefuehrt:\nSystem :  $RHOST\nPfade  : $RPATH\n\n-------------------------------------------------\n\n`cat $STAT/rsync.stat.0`"
if [ $DEBUG == "yes" ] ; then
    echo "Die Logeintrage werden per Email versendet!"
    SUBJECT="$SUBJECTSUC"
    MESSAGE="##### DEBUG-Durchlauf #####\n\n$MESSAGE"
    echo -e "\n### MAIL ###"
    echo -e "echo -e \"From: $FROM\nSubject: $SUBJECT\n\n ##MESSAGE##\" | $SENDMAIL $MAIL"
    echo -e "### MAIL ###\n"
    echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $MAIL
else
    SUBJECT="$SUBJECTSUC"
    echo -e "From: $FROM\nSubject: $SUBJECT\n\n$MESSAGE" | $SENDMAIL $ADMINMAIL
fi


# Zeit speichern in der das Backup fertiggestellt wurde
####################################################################################################

if [ $DEBUG == "yes" ] ; then
    echo "Die aktuelle Zeit wird im Backup-File festgehalten, durch:"
    echo -e "touch $LPATH/backup.0 \n"
    else
	touch $LPATH/backup.0
fi

if [ $DEBUG == "yes" ] ; then
    echo "Backup-Skript ist durchgelaufen!"
fi


# FERTIG.
####################################################################################################
exit 0
