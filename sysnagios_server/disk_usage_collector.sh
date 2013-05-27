#!/bin/bash
#
# 2007-02-23, frwa02 updated to accept nrpe-port as 4'th argument
# 2007-02-23, frwa02 updated to accept $ARG2$ as 5'th argument
#
DEBUG=0
debug() {
	if [ $DEBUG -eq 1 ]; then
		echo "$1"
	fi
}

debugutskrift() {
if [ $DEBUG -eq 2 ]; then
	dejt=`date`
	echo "$1 $dejt" >> /tmp/disk_usage_collector.txt
fi
}

debugutskrift "disk_usage_collector startat"

if [ $# -lt 3 ]; then
	echo "USAGE: disk_usage_collector.sh <HOSTNAME> <SERVICEDESCRIPTION> <TIMESTAMP> [NRPE-Port] [extra arguments]"
	exit 0
fi


#Read arguments from the command-line
HOST=$1
SVCNAME=$2
TIME=$3

if [ `hostname` = nagiostest ]; then
	NRPE_PORT=${NRPE_PORT:=1987}
else
	NRPE_PORT=${NRPE_PORT:=2004}
fi

if [ -n "$4" ] ; then
	NRPE_PORT=$4
fi

if [ `hostname` = antnagios.sun.telia.se -a $NRPE_PORT=1987 ] ; then NRPE_PORT=2004; fi

RETVAL=0
RETSTR=""

# bastard1_disk_usage_check_disk_data.rrd
RRDDIR=/usr/local/nagios/rrd
RRDFILE=${RRDDIR}/${HOST}_disk_usage_${SVCNAME}.rrd
RRDTOOL=/usr/local/bin/rrdtool
CHECK_NRPE="/usr/local/nagios/libexec/check_nrpe $5 -t 60 -p $NRPE_PORT"


if [ ! -f $RRDFILE ]; then
	debug "The $RRDFILE file will be created now"
	$RRDTOOL create $RRDFILE DS:Used:GAUGE:1800:0:100 RRA:AVERAGE:0.5:1:50400 RRA:AVERAGE:0.5:60:43800
#	exit 3
else
	if [ ! -w $RRDFILE ]; then
		echo "RRDFILE $RRDFILE not writable"
		exit 3
	fi
fi

# DEBUG XXX
#echo "$CHECK_NRPE -H $HOST -c $SVCNAME" >> /tmp/disk_usage_collector_debug.txt
RETSTR=`$CHECK_NRPE -H $HOST -c $SVCNAME`
RETVAL=$? 

debugutskrift "disk usage: Check_rpe: $RETSTR, $RETVAL"

# check_disk finns i en nyare version med liten annan output
if [ `echo $RETSTR | grep inode=  | wc -l` -gt 0 ];then
    INODE_TMP=`echo $RETSTR| cut -d "=" -f 2 | awk '{ print $1 }' | tr -d '\|\;\)'` 
		UTIL66=`echo $RETSTR|cut -d "k" -f 2|cut -d "=" -f 3 | sed '{s/MB.*$//g}'`
 else
    UTIL66=`echo $RETSTR|cut -d "k" -f 2|cut -d "=" -f 2 | sed '{s/MB.*$//g}'`
fi
UTIL67=`echo $RETSTR|cut -d ";" -f 6`
USAGE=`echo "scale=2; $UTIL66/$UTIL67*100"|bc -l|cut -d "." -f 1`
#echo $RETSTR
#echo "UTIL66: $UTIL66 UTIL67: $UTIL67 USAGE: $USAGE INODE_TMP: $INODE_TMP"

DATA="$TIME:$USAGE"
debugutskrift "** util66: $UTIL66 util67: $UTIL67 $DATA **"

if $RRDTOOL update $RRDFILE -t Used $DATA ;then
	debugutskrift "$RRDTOOL update $RRDFILE -t Used $DATA" 
	debug "Inserting $DATA into $RRDFILE"
else
	echo "${HOST}:${SVCNAME}, Could not insert Usage , $DATA into $RRDFILE"
	exit 2
fi

debug "Returning '$RETSTR' , $RETVAL"
debugutskrift "Returning and echoieng"

echo $RETSTR
exit $RETVAL
