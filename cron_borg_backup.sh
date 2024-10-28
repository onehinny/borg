#!/bin/sh

BACKUP_MAC=9c:b6:54:06:6c:a0
BACKUP_IP=192.168.10.32

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
ntfy() {
   curl -s -H "X-Tags: backup" -d "$1" https://ntfy.matthiasstein.net/backup
  }

ntfy_critical() {
  curl -s -H "X-Tags: warning, backup" -H "Title: $1" -H "Priority: urgent" -H "Tags: warning" -d "$2" https://ntfy.matthiasstein.net/backup 
}

ntfy_success() {
  curl -s -H "X-Tags: backup" -H "Title: $1" -H "Tags: white_check_mark" -d "$2" https://ntfy.matthiasstein.net/backup 
}


trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "****************************************************"

BACKUP_PATH=/mnt/data/
REPO_NAME=homelab

ntfy "Starting backup"

info "Using data $BACKUP_PATH to backup $REPO_NAME"


# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=backup:$REPO_NAME

# use the "pass" password manager to get the passphrase:
export BORG_PASSCOMMAND='pass Backup/borg_passphrase'

info "Send magic pattern to wake machine"

etherwake -i eno1 $BACKUP_MAC

info "Wait until ssh works"
until borg info backup:$REPO_NAME; do echo "..waiting..."; sleep 15 ; done
# sleep 180

info "Starting backup"

# Backup the most important directories into an archive named after
# the machine this script is currently running on:

borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    --exclude-caches                \
    --exclude "logs"                \
    --exclude "*.log"               \
    --exclude "*.log"               \
    --exclude "*/.git"              \
                                    \
    ::'{hostname}-{now}'            \
    $BACKUP_PATH/authelia           \
    $BACKUP_PATH/homeassistant      \
    $BACKUP_PATH/immich             \
    $BACKUP_PATH/nextcloud          \
    $BACKUP_PATH/onlyoffice         \
    $BACKUP_PATH/paperless          

backup_exit=$?

info "Pruning repository"

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}-*' matching is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                          \
    --list                          \
    --glob-archives '{hostname}-*'  \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6

prune_exit=$?

# actually free repo disk space by compacting segments

info "Compacting repository"

borg compact

compact_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
global_exit=$(( compact_exit > global_exit ? compact_exit : global_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
    ntfy_success "Backup successfull" "Backup, Prune, and Compact finished successfully" 
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
    ntfy_critical "Backup successfull" "Backup, Prune, and/or Compact finished with warnings"
else
    info "Backup, Prune, and/or Compact finished with errors"
    ntfy_critical "Backup successfull" "Backup, Prune, and/or Compact finished with errors"
fi

exit ${global_exit}
