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
	echo "$1 $dejt" >> /tmp/perf_collector.txt
fi
}

debugutskrift "perf_collector startat"

if [ $# -lt 3 ]; then
	echo "USAGE: perf_collector.sh <HOSTNAME> <SERVICEDESCRIPTION> <TIMESTAMP> [NRPE-Port] [extra args]" 
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

if [ -n "$4" ]; then
	NRPE_PORT=$4
fi

if [ `hostname` = antnagios.sun.telia.se -a $NRPE_PORT -eq 1987 ]; then
	NRPE_PORT=2004
fi

RETVAL=0
RETSTR=""

RRDDIR=/usr/local/nagios/rrd
RRDFILE=${RRDDIR}/${HOST}_perf_${SVCNAME}.rrd
RRDTOOL=/usr/local/bin/rrdtool
CHECK_NRPE="/usr/local/nagios/libexec/check_nrpe -t 60 $5 -p $NRPE_PORT"

#echo "Nrpe: '$CHECK_NRPE', 1: '$1' 2: '$2' 3: '$3' 4: '$4' 5: '$5'" >> /tmp/aaaa.log

if [ ! -f $RRDFILE ]; then
	debug "The $RRDFILE file will be created now"
	$RRDTOOL create $RRDFILE DS:usr:GAUGE:1800:0:100 DS:sys:GAUGE:1800:0:100 DS:wio:GAUGE:1800:0:100 DS:usage:GAUGE:1800:0:100 RRA:AVERAGE:0.5:1:50400 RRA:AVERAGE:0.5:60:43800
#	exit 3
else
	if [ ! -w $RRDFILE ]; then
		echo "RRDFILE $RRDFILE not writable"
		exit 3
	fi
fi

RETSTR=`$CHECK_NRPE -H $HOST -c $SVCNAME`
RETVAL=$? 

debug "retstr:$RETSTR"
debugutskrift "disk usage: Check_rpe: $RETSTR, $RETVAL"

#UTIL66=`echo $RETSTR|cut -d "k" -f 2|cut -d "=" -f 2 | sed '{s/MB.*$//g}'`
#UTIL67=`echo $RETSTR|cut -d ";" -f 6`
#USAGE=`echo "scale=2; $UTIL66/$UTIL67*100"|bc -l|cut -d "." -f 1`
usr=`echo $RETSTR|cut -d \| -f 2| cut -d \; -f 1`
sys=`echo $RETSTR|cut -d \| -f 2| cut -d \; -f 2`
wio=`echo $RETSTR|cut -d \| -f 2| cut -d \; -f 3`
usage=`echo $RETSTR|cut -d \| -f 2| cut -d \; -f 4`

debug "usr:$usr sys:$sys wio:$wio usage:$usage"


DATA="$TIME:$usr:$sys:$wio:$usage"

if $RRDTOOL update $RRDFILE -t usr:sys:wio:usage $DATA ;then
	debugutskrift "$RRDTOOL update $RRDFILE -t usr:sys:wio:usage $DATA" 
	debug "Inserting $DATA into $RRDFILE"
else
	echo "${HOST}:${SVCNAME}, Could not insert Usage , $DATA into $RRDFILE"
	exit 2
fi

debug "Returning '$RETSTR' , $RETVAL"
debugutskrift "Returning and echoieng"

echo $RETSTR
exit $RETVAL
