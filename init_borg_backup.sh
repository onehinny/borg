sudo apt install -y \
  borgbackup \
  etherwake \
  pass

export BORG_PASSCOMMAND='pass Backup/borg_passphrase'
borg init --encryption=repokey-blake2 backup:homelab
