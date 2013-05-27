#!/bin/sh 
# 2007-02-22 Fredrik W Added support for nrpe port-number. To use another port
#                      than default, specify <host>:<port>.
# 2007-03-12 Fredrik W Added possibility to skip SSL. If you dont want SSL,
#                      specify <host>:<port>:nossl

DEBUG=0
if [ $DEBUG -lt 2 ]; then
	. /etc/sysnagios.conf
else 
	. /home/xz1862/pkg/sysnagios_server/sysnagios.conf
fi

if [ $DEBUG -gt 0 ]; then
	set -x
fi

BASE_DIR=$SYSNAGIOS_HOME
HOSTS=${BASE_DIR}/autohosts.cfg
TEMP_TARFILE=/tmp/$$.config.tar

if [ -f $ERRORLOG ]; then rm $ERRORLOG; fi

apan_check() {
#Check new config file for apan configuration
#Usage: ./apanadd.sh <hostname> <service> <RRDfile> <graph-label> <graph-unit> <extra rrd-args> <step> <comment> <rra-1> <rra-2 .. <rra-n>

  for servicefile in `tar ${TARFLAGS}ft $TEMP_TARFILE`; do
	cat ${CONFIG_DIR}/$servicefile | sed -n '/^#::apan/p'| sed 's/#::apan//' | while read -a array
	  do
		  apan_check_host=`echo $servicefile | cut -d _ -f 1`
		  apan_alias=`echo ${array[1]} | cut -c 0-18`
		  apan_plugin=${array[0]}
		  case ${array[0]} in
		  'disk_gb')
			  title="Disk Usage: ${array[1]}"
			  apan_alias=`echo ${array[1]} | cut -c 0-18`
			  $APANADM_DIR/apanadd.sh $apan_check_host ${array[1]} ${RRDIR}/${apan_check_host}_${apan_plugin}_${array[1]}.rrd "$title" Gb '-l 0' 60 '' ${array[1]} $apan_alias 1 1 900 0 1000 LINE2
			  ;;
		  'disk_usage')
			  title="Disk Usage: ${array[1]}"
			  $APANADM_DIR/apanadd.sh $apan_check_host ${array[1]} ${RRDIR}/${apan_check_host}_disk_usage_${array[1]}.rrd "$title" % '-l 0 -u 100 --rigid' 60 '' ${array[1]} $apan_alias 1 1 900 0 100 LINE2
			  ;;
		  'unix_performance')
			  title="Performance: ${array[1]}"
			  $APANADM_DIR/apanadd.sh $apan_check_host ${array[1]} ${RRDIR}/${apan_check_host}_${array[1]}.rrd "$title" % '-l 0' 60 '' ${array[1]} ${array[1]} 1 1 900 0 100 LINE2
					;;
		  esac
	  done
  done
}

############################### Main....

if [ $# -gt 0 ]; then
	hosts=$@
elif [ `hostname`!='nagiostest' ]; then
	#Just search all hosts currently on this server.
	hosts=`find $CONFIG_DIR -name \*.cfg -exec cat {} \;| sed -n '/define host/,/}/{p}' | awk '/host_name/{print $2}' | xargs echo`
else
	hosts=`cat $HOSTS`
fi

updated=0
for host in $hosts; do
  echo $host
  #Check if host:port is specified
  NRPE_PORT=`echo $host|awk -F: '{print $2}'`
	#If port is not specified, use default values depending on hostname
	if [ `hostname` = nagiostest ]; then
		echo "HOSTNAME antnagios"
		NRPE_PORT=${NRPE_PORT:=1987}
	else
		NRPE_PORT=${NRPE_PORT:=2004}
	fi

  NOSSL=`echo $host|awk -F: '{print $3}'|egrep -e '^nossl$|^NOSSL$'|wc -l|awk '{print $NF}'`
  if [ $NOSSL -gt 0 ]; then echo "NS: $NOSSL"; fi
	if [ $NOSSL = 1 ]; then
		EXTRA_NRPE_ARGS="-n"
	fi


  hostname=`echo $host|awk -F: '{print $1}'`
	if $NRPE_CHECK -H $hostname $EXTRA_NRPE_ARGS -p $NRPE_PORT >/dev/null; then
		echo "update $hostname"
		cd $CONFIG_DIR
		if [ -f $TEMP_TARFILE ] ; then rm $TEMP_TARFILE; fi
		# Unixify the file just to be sure

		#${BASE_DIR}/gethex $hostname $NRPE_PORT "$EXTRA_NRPE_ARGS" | dos2unix | ${BASE_DIR}/hex2ascii >> $TEMP_TARFILE

		set -x
		cat /usr/local/nagios/etc/config.hex |  ${BASE_DIR}/hex2ascii >> $TEMP_TARFILE 
		# Check if input is gzipped
		filetype=`file $TEMP_TARFILE | cut -d: -f2 | awk '{ print $1 }'`
		case $filetype in
			'tar')
					echo "Input is uncompressed"
					TARFLAGS=""
					tar xf $TEMP_TARFILE
					apan_check
					updated=1
					;;
			'gzip')
					echo "Input is GZIPPED, unzipping"
					if [ "`tar tfz $TEMP_TARFILE`" = "nrpe.tmp" ] ; then
						echo "nrpe.tmp found. Will create services on the server"
						#Make sure there is no nrpe.tmp
						if [ -f /tmp/nrpe.tmp ] ; then rm /tmp/nrpe.tmp; fi
						mkdir /tmp/temp.$$
						cd /tmp/temp.$$
						tar xfz $TEMP_TARFILE
						if $BASE_DIR/create_services.sh /tmp/temp.$$/nrpe.tmp 
						then
							updated=1
						fi
						if [ $DEBUG -eq 0 ]; then
							rm -rf /tmp/temp.$$
						fi
					else
						echo "Unix configfile"
						TARFLAGS=z
						tar xfz $TEMP_TARFILE
						apan_check
						updated=1
					fi
					;;
			'data')
					echo "$host failed" >> $ERRORLOG
					;;
			'empty')
					echo "$host failed" >> $ERRORLOG
					;;
		esac

		else
		echo "$hostname - no new config"
	fi
done

if [ $updated -eq 1 ]; then
	cd $CONFIG_DIR
	chown -R $NAGIOS_USR_GRP *
	#eval $NAGIOS_RELOAD_CMD 
else
	echo "No updates"
fi

if [ -f $TEMP_TARFILE ] ; then rm $TEMP_TARFILE; fi
