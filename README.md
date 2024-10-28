# borg
scripts for backups

## Crontab
05 03 * * * ~/borg/cron_borg_backup.sh >> ~/borg/logs/cron-`date +\%F`.log 2>&1
