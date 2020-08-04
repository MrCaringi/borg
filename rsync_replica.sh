#!/bin/bash

###############################
#               RSYNC Replica v2
#   This is scripts is for RSYNC your folders from a server to other
#
##   HOW TO USE (put it in crontab)
#	    0 12 * * * bash /path/rsync_replica.sh /path/to/rsync_replica.json >> /path/log
#
##  PARAMETERS
#   $1  Path to ".json" config file
#
##   REQUIREMENTS
#       - to be able to ssh to host without password (it requires a proper ssh configuration: SSH PUB KEY Configuration)
#       - RSYNC daemon should be available on destination
#       - "sshpass" packacge is needed in the source server.
#
##	RSYNC CONFIGURATION
#   Please see https://github.com/MrCaringi/borg for a example of "rsync_replica.json" file
#
#  It must include:
#  In CONFIG section
#       "Network": IP of your local network, example, if your server IP is 1.1.1.22/24, then your network address is 1.1.1.0
#       "Seconds": Seconds to wait in order to verifiy if remote server is UP
#       "Try": Seconds to wait between attempts if server is up
#       "SendMessage": full pathand ans script name used for Telegram send Message
#       "SendFile": full pathand ans script name used for Telegram send File Log
#
#   In DESTINATION section
#       "Host": Hostname of remote server
#        "RsyncUser": Rsync user in remote server
#        "RsyncPass": Rsync password in remote server
#        "IPDest": IP of remote server
#        "MAC": MAC address of remote server
#        "Share": Shared folder in remote server
#
#   in FOLDERS section
#       Just the array of folders to replicate to remote server
#
##	SCRIPT MODIFICATION NOTES
#       2020-04-28  First version
#       2020-04-29  Testing version releases	
#       2020-04-30  Variables improvement
#       2020-05-01  Shutdown fix
#       2020-08-04  Version 2: JSON config support
#
###############################

##      Getting the Configuration
#   General Config
IP=`cat $1 | jq --raw-output '.config.Network'`
SEC=`cat $1 | jq --raw-output '.config.Seconds'`
TRY=`cat $1 | jq --raw-output '.config.Try'`
SEND_MESSAGE=`cat $1 | jq --raw-output '.config.SendMessage'`
SEND_FILE=`cat $1 | jq --raw-output '.config.SendFile'`
#   Destination Config
HOST=`cat $1 | jq --raw-output '.destination.Host'`
RSYNCUSER=`cat $1 | jq --raw-output '.destination.RsyncUser'`
RSYNCPASS=`cat $1 | jq --raw-output '.destination.RsyncPass'`
IPRSYNC=`cat $1 | jq --raw-output '.destination.IPDest'`
MAC=`cat $1 | jq --raw-output '.destination.MAC'`
SHARE=`cat $1 | jq --raw-output '.destination.Share'`
#   Folders Config
DIR_LIST=`cat $1 | jq --raw-output '.folders[]'`

##   Starting WOL
    echo "=============================================================================="
    echo $(date +%Y%m%d-%H%M)" WOL of device $IP $MAC"
    bash $SEND_MESSAGE "RSYNC Replica" "WOL device $HOST ($IPRSYNC)" > /dev/null
    
    wakeonlan -i $IP $MAC

##  Verifying if WOL was OK   
    UP=0
    T=0
    while [ UP -eq 0 ]
        do 
            ping -c 1 $IPRSYNC 
            if [ $? -ne 0 ]; then
                echo $(date +%Y%m%d-%H%M)" ERROR during WOL of $HOST, ping unsuccessful"
                sleep $SEC
                T=$(( $T + 1 ))
            else
                UP=1
                echo $(date +%Y%m%d-%H%M)" WOL of $HOST, ping successful, waiting for Remote Host to be fully ready"
                sleep $SEC
            fi
            if [ $T -ge $TRY ]; then
                echo $(date +%Y%m%d-%H%M)" ERROR during WOL of $HOST, after $T attempts of $SEC Seconds"
                bash $SEND_MESSAGE "RSYNC Replica" "ERROR during WOL, after $T attempts of $SEC Seconds" "of $HOST" > /dev/null
                exit 1
        done

##  If WOL was ok, then is time to RSYNC
    for i in $DIR_LIST
    do
        echo "================================================"
        DIR=${i##*/}
        echo $(date +%Y%m%d-%H%M)" Starting RSYNC of $DIR"
        START=$(date +"%Y%m%d %HH%MM%SS")
        bash $SEND_MESSAGE "RSYNC Replica to" "RSYNCing #${DIR}"> /dev/null
        
        #   The Magic goes here
        LOG=`sshpass -p $RSYNCPASS rsync -aq --append-verify $i $RSYNCUSER@$IPRSYNC::$SHARE 2>&1`
        if [ $? -ne 0 ]; then
            echo $(date +%Y%m%d-%H%M)" ERROR RSYNC $DIR"
            bash $SEND_MESSAGE "RSYNC Replica" "ERROR during RSYNCing " "#${DIR}" > /dev/null
            
            ##  Sending log to Telegram
            #   Building the log file
                rand=$((1000 + RANDOM % 8500))
                echo "========== RSYNC Replica          $START" >> rsync-log_${rand}.log
                echo "$LOG" >> rsync-log_${rand}.log
                echo >> rsync-log_${rand}.log
                echo "========== END           $(date +"%Y%m%d %HH%MM%SS")" >> rsync-log_${rand}.log
                #   Sending the File to Telegram
                bash $SEND_FILE "RSYNC Replica" "ERROR during RSYNCing #${DIR}" rsync-log_${rand}.log > /dev/null
                #   Flushing & Deleting the file
                cat rsync-log_${rand}.log
                rm rsync-log_${rand}.log

            sleep 5
        fi
    done

##   Turning off remote device
    echo $(date +%Y%m%d-%H%M)" RSYNC Finished on $HOST"
    bash SEND_MESSAGE "RSYNC Replica" "RSYNC Finished on" "$HOST ($IPRSYNC)" > /dev/null
    sleep 5
    echo $(date +%Y%m%d-%H%M)" Shutting Down $HOST"
    ssh -t $HOST "sudo shutdown -h now"
    sleep 5
    exit 0
