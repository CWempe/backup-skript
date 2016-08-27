# backup-skript

## get_backup_size.sh

to get the size of each backup use this command:
```bash
./get_backup_size.sh /mybackupfolder/hostname
```

example output:
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
