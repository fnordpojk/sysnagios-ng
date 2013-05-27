#!/bin/bash

DEBUG=0
debug() {
	if [ $DEBUG -eq 1 ]; then
		echo "$1"
	fi
}

debugutskrift() {
if [ $DEBUG -eq 2 ]; then
	dejt=`date`
	echo "$1 $dejt" >> /tmp/disk_gb_collector.txt
fi
}

debugutskrift "disk_gb_collector startat"

if [ $# -lt 3 ]; then
	echo "USAGE: disk_gb_collector.sh <HOSTNAME> <SERVICEDESCRIPTION> <TIMESTAMP> [NRPE-Port] [Extra args]"
	exit 0
fi


#Read arguments from the command-line
HOST=$1
SVCNAME=$2
TIME=$3
NRPE_PORT=$4
#NRPE_PORT=${NRPE_PORT:=2004}

if [ `hostname` = antnagios.sun.telia.se -a $NRPE_PORT=1987 ] ; then NRPE_PORT=2004; fi

RETVAL=0
RETSTR=""

# bastard1_disk_gb_check_disk_data.rrd
RRDDIR=/usr/local/nagios/rrd
RRDFILE=${RRDDIR}/${HOST}_disk_gb_${SVCNAME}.rrd
RRDTOOL=/usr/local/bin/rrdtool
#NRPE_PORT=1987
CHECK_NRPE="/usr/local/nagios/libexec/check_nrpe $5 -p $NRPE_PORT"


if [ ! -f $RRDFILE ]; then
	debug "The $RRDFILE file will be created now"
	$RRDTOOL create $RRDFILE DS:Used:GAUGE:1800:0:U RRA:AVERAGE:0.5:1:50400 RRA:AVERAGE:0.5:60:43800
	#exit 3
else
	if [ ! -w $RRDFILE ]; then
		echo "RRDFILE $RRDFILE not writable"
		exit 3
	fi
fi

RETSTR=`$CHECK_NRPE -H $HOST -c $SVCNAME`
RETVAL=$? 

debugutskrift "Check_rpe: $RETSTR, $RETVAL"

# check_disk finns i en nyare version med liten annan output
if [ `echo $RETSTR | grep inode=  | wc -l` -gt 0 ];then
    INODE_TMP=`echo $RETSTR| cut -d "=" -f 2 | awk '{ print $1 }' | tr -d '\|\;\)'`
    UTIL66=`echo $RETSTR|cut -d "|" -f 2|cut -d "=" -f 2 | sed '{s/MB.*$//g}'`
 else
    UTIL66=`echo $RETSTR|cut -d "k" -f 2|cut -d "=" -f 2 | sed '{s/MB.*$//g}'`
fi
#GB=`echo "scale=2; $UTIL66/1024" | bc -l | cut -d "." -f 1`
GB=`echo "scale=0; $UTIL66/1024" | bc -l`
DATA="$TIME:$GB"

if $RRDTOOL update $RRDFILE -t Used $DATA ;then
	echo "$RRDTOOL update $RRDFILE -t Used $DATA" >> /tmp/disk_gb_collector.txt
	debug "Inserting $DATA into $RRDFILE"
else
	echo "${HOST}:${SVCNAME}, Could not insert Usage , $DATA into $RRDFILE"
	exit 2
fi

debug "Returning '$RETSTR' , $RETVAL"
debugutskrift "Returning and echoieng"

echo $RETSTR
exit $RETVAL
