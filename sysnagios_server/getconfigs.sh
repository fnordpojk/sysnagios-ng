#!/bin/sh 
# 2007-02-22 Fredrik W Added support for nrpe port-number. To use another port
#                      than default, specify <host>:<port>.
# 2007-03-12 Fredrik W Added possibility to skip SSL. If you dont want SSL,
#                      specify <host>:<port>:nossl

DEBUG=1

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
  TMP_PORT=`echo $host|awk -F: '{print $2}'`
	if [ -n "$TMP_PORT" ]; then
		NRPE_PORT=$TMP_PORT
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
		${BASE_DIR}/gethex $hostname $NRPE_PORT "$EXTRA_NRPE_ARGS" | dos2unix | ${BASE_DIR}/hex2ascii >> $TEMP_TARFILE

		# Check if input is gzipped
		filetype=`file $TEMP_TARFILE | cut -d: -f2 | awk '{ print $1 }'`
		case $filetype in
			'tar')
					echo "Input is uncompressed"
					TARFLAGS=""
					tar xf $TEMP_TARFILE
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
						if [ "$DEBUG" -eq 0 ]; then
							rm -rf /tmp/temp.$$
						fi
					else
						echo "Unix configfile"
						TARFLAGS=z
						tar xfz $TEMP_TARFILE
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

if [ -f $TEMP_TARFILE ] ; then rm $TEMP_TARFILE; fi
