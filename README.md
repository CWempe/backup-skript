# backup-skript

## get_backup_size.sh

To get the size of each backup use this command:

```bash
./get_backup_size.sh /mybackupfolder/hostname
```

Example output:

```
289G    backup.29
2,3G    backup.28
102M    backup.27
1,4G    backup.26
3,5G    backup.25
840M    backup.24
653M    backup.23
827M    backup.22
789M    backup.21
6,3G    backup.20
109M    backup.19
6,1G    backup.18
2,0G    backup.17
1,2G    backup.16
1,3G    backup.15
866M    backup.14
1,2G    backup.13
1,3G    backup.12
778M    backup.11
1,5G    backup.10
1,8G    backup.9
1,7G    backup.8
1,6G    backup.7
1,9G    backup.6
1,7G    backup.5
106M    backup.4
106M    backup.3
106M    backup.2
106M    backup.1
106M    backup.0
331G    insgesamt
```

You might need to install full versions of ls and du on your qnap via Entware-ng.
BusyBox does not support all necessary options.

## show_backup_sizes.sh

To get a visual of the size of all backup jobs you can run this script.
Firt it checks the hosts in the backup target dir and asks wich one you want to see.
Then it reads the values from the .stat files and displays the total size and the diff size of each backup job as a colorful graph.

You need the python module `termgraph` to use this.

```shell
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```