#!/bin/sh

###############################
#  BORG BACKUP SCRIPT
#
#	sh borg-b.sh DOCKER /mnt/iscsi-borg/nostromo-docker /mnt/nostromo-docker 7 4 3
#
#	Parametros
#	1 $TITLE - Titulo del Backup	DOCKER 
#	2 $REP - Repositorio, ejemplo 	/mnt/iscsi-borg/nostromo-docker
#	3 $ORI - Origen, ejemplo	/mnt/nostromo-docker
#	4 $D - Prune Days	7
#	5 $W - Prune Weeks	4
#	6 $M - Prune Months	6
#
#	Modification Log
#		2020-04-24  First version
#		2020-04-25  Uploaded a GitHub version
#
#
###############################

#	Asignacion de Variables
TITLE="${1}-$(date +"%Y%m%d")"
REP=${2}
ORI=${3}
D=${4}
W=${5}
M=${6}

#	Ruta de repositorio + nombre de backup
FULLREP="${REP}::${TITLE}"

#	Carga de Password, ejemplo del contenido: PASSPHRASE='password'
. /home/jfc/scripts/borg.conf

echo "=============================================================================="

# Setting this, so the repo does not need to be given on the command line:
export BORG_REPO=$REP

###	TESTING
#echo "repositorio ${REP}"
#echo "origen" ${ORI}
#echo "BORG_REPO=$REP"
#exit

# Setting this, so you won't be asked for your repository passphrase:
export BORG_PASSPHRASE=${PASSPHRASE}
# or this to ask an external program to supply the passphrase:
# export BORG_PASSCOMMAND='pass show backup'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Starting backup"
bash /home/jfc/scripts/telegram-message.sh "Borg Backup" "Repo: ${TITLE}" "Starting backup" > /dev/null

# Backup the most important directories into an archive named after
# the machine this script is currently running on:

borg create -v :-stats --compression auto,zlib,5 ${FULLREP} ${ORI}

backup_exit=$?

info "Pruning repository"
bash /home/jfc/scripts/telegram-message.sh "Borg Backup" "Repo: ${TITLE}" "Pruning repository" > /dev/null

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The 'QNAP-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune -v -s --list --keep-daily=$D --keep-weekly=$W --keep-monthly=$M $REP

prune_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup and Prune finished successfully"
	bash /home/jfc/scripts/telegram-message.sh "Borg Backup" "Repo: ${TITLE}" "Backup and Prune finished successfully" > /dev/null
elif [ ${global_exit} -eq 1 ]; then
    info "Backup and/or Prune finished with warnings"
	bash /home/jfc/scripts/telegram-message.sh "Borg Backup" "Repo: ${TITLE}" "Backup and/or Prune finished with warnings" > /dev/null
else
    info "Backup and/or Prune finished with errors"
	bash /home/jfc/scripts/telegram-message.sh "Borg Backup" "Repo: ${TITLE}" "Backup and/or Prune finished with errors" > /dev/null
fi

exit ${global_exit}
