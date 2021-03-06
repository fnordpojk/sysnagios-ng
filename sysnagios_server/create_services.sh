#!/bin/sh
#####
# This script tries to extract an services.cfg for use in nagios server configuration
# It is extracted from the nrpe.cfg file in /nfs/drift/nagios/etc/nrpe.cfg
#
# 2004-11-26 erbo10
# 2005-01-12 erbo10 added # check_START and # check_END, added support for # in services-file
# 2005-01-31 maan21 change name of SERVICES_OUTDIR.
# 2005-12-13 erbo10 configure for balder5
# 2006-01-31 erbo10 one service-file per host
# 2006-03-15 erbo10 adderade hosts configuration per fil
# 2007-02-22 frwa02 Added function that reads Nrpe-port from nrpe.cfg
# 2007-03-12 frwa02 Added function that reads #::ssl/#::nossl and creates service/host-
#                   definitions with or without SSL.
# 2007-12-13 xz1862 Changed to run on the server
#
#####

# usage: create_services <filename> 
# l�sa in funktionen questions f�r att kunna st�lla fr�gor

#######
# CONFIG

PID=$$

DEBUG=0
if [ $DEBUG -lt 2 ]; then
	. /etc/sysnagios.conf
else
	#. /home/xz1862/pkg/sysnagios_server/sysnagios.conf
	:
fi

. $SYSNAGIOS_HOME/functions.sh
. $SYSNAGIOS_DEFS

CONFIG_FILE=$1
TMP_CONFIG_FILE=$CONFIG_FILE

#TEMPDIR=/tmp/tempdir.$$
#if [ ! -d $TEMPDIR ]; then mkdir $TEMPDIR; fi

#SERVICES_OUTDIR �r kanske lite missvisande nu, eftersom det fortfarande �r en 
# tempkatalog. Detta �r en rest fr�n tidigare. 
SERVICES_OUTDIR=$TEMPDIR

#NRPE_PORT=`grep "^server_port=" $CONFIG_FILE|awk -F= '{print $2}'`
#NRPE_PORT=${NRPE_PORT:=1987}
debug "NRPE_PORT: $NRPE_PORT"

if [ $DEBUG -gt 1 ]; then
	set -x
fi

#######

cd $TEMPDIR

#################################################################### Main

if [ -s $CONFIG_FILE ];then
debug "#### Configfilerna finns"
debug "CONFIG_FILE=${CONFIG_FILE}"

# Get commands
debug "***** start main loop ****** "
# If a tag is used to set ip, dont query for it. 
hardip=0
sed 's/\r//g' $TMP_CONFIG_FILE > /tmp/hej.$$
mv /tmp/hej.$$ $TMP_CONFIG_FILE
sed -n '/^#::check_START/,/^#::check_END/{;s/^# +/#/;/^$/d;/^command/p;/^#::/p;}' $TMP_CONFIG_FILE | sed 's/#:://' | cut -d= -f1 | tr '\[\]' '  ' | while read c a
   do
		debug "$c $a"
		case $c in
			'hvar')
				#echo $a
				varname=""
				val=""
				varname=`echo "$a"| cut -d" " -f1`
				val=`echo "$a"| cut -d" " -f2-30`
				HVARS="$varname $HVARS"
				eval `printf 'hvar_%s="%s"' "$varname" "$val"`
				;;
			'svar')
				#echo $a
				varname=""
				val=""
				varname=`echo "$a"| cut -d" " -f1`
				val=`echo "$a"| cut -d" " -f2-30`
				SVARS="$varname $SVARS"
				eval `printf 'svar_%s="%s"' "$varname" "$val"`
				;;
			'nossl')
				CHECK_NRPE=$CHECK_NRPE_NOSSL
				USESSL=0
				NRPE_ARGS="-n"
				SSL="nossl"
				;;
			'ssl')
				CHECK_NRPE=$CHECK_NRPE_SSL
				USESSL=1
				NRPE_ARGS=""
				SSL_URL="&ssl=ssl"
				SSL="ssl"
				;;
			'hostname') 
				# If you want servicechecks to be associated with another host
				# use with caution
				HOST=$a
				;;
			'host_start') 
				# Get IP for the host
				# Get hostname from nrpe-file 
				HOST=$a
				get_services $a
				# Get ip only if it is'nt set in the nrpe.cfg file
				if [ $hardip -eq 0 ] ; then get_ip $HOST;  fi
				if [ -z $ip ]; then 
					echo "NO IP $HOST"
					exit 1
				fi
				write_host "$HOST" "$ALIAS" "$CONTACT" "$SLA" "$ip"
				;;
			'check_command')
				check_command=$a
				;;
			'check_command_args')
				check_command_args=$a
				;;
			'hostgroup')
				HOSTGROUP=$a
				;;
			'max_check_attempts')
				max_check_attempts=$a
				;;
			'hostgroups')
				HOSTGROUP=$a
				;;
			'action_url') 
				action_url=$a
				;;
			'notes') 
				NOTES=$a
				;;
			'host_end') 
				
				delete_global_services
				if [ -z $rollback_rollback ]; then
					save
				fi

	
				HOST="" 
				;;
			'alias')
				ALIAS=$a
				;;
			'contact_groups')
				CONTACT=$a;
				debug "### Contact: $CONTACT"
				;;
			'contactgroups')
				CONTACT=$a;
				debug "### Contact: $CONTACT"
				;;
			'contacts')
				CONTACTS=$a;
				debug "### Contact: $CONTACT"
				;;
			'contact')
				CONTACTS=$a;
				debug "### Contact: $CONTACT"
				;;
			'check_interval')
				check_interval=$a;
				;;
			'retry_interval')
				retry_interval=$a;
				;;
			'servicegroups')
				SERVICEGROUPS=$a
				;;
			'host_template')
				HOST_TEMPLATE=$a
				;;
			'template_host')
				HOST_TEMPLATE=$a
				;;
			'service_template')
				SERVICE_TEMPLATE=$a
				;;
			'template_service')
				SERVICE_TEMPLATE=$a
				;;
			'check_period')
				CHECK_PERIOD=$a
				;;
			'command')
				if [ "$USESSL" = 1 ]; then
					ZZL="";
				else 
					ZZL="'!-n"
				fi
				write_services "$HOST" "$a" "$CONTACT" "$SLA" "$CHECK_NRPE!$a!$NRPE_PORT$ZZL"
				pop_service "$a"
				;;
			'notification_period')
				SLA=$a
				debug "notificatiopn_period/SLA=$a"
				;;
			'sla')
				SLA=$a
				debug "SLA=$a"
				;;
			'ip')
				ip=$a
				hardip=1
				debug "ip=$a"
				;;
			'port')
				NRPE_PORT=$a
				debug "NPRE_PORT=$a"
				;;
		esac
   done
 else
   echo "No $nrpe.cfg"
fi

exit

########## Now test the new files.


# Save a copy of the config file
cd $TEMPDIR
mkdir oldconfigs
for file in `ls *.cfg` ; do
	if [ -f $CONFIG_DIR/$file ]; then
		mv $CONFIG_DIR/$file $TEMPDIR/oldconfigs
	fi

	if [ `hostname` = nagiostest ] ; then
		#Check if the host is in nagios.cfg. If it is'nt, add it.
		if  grep \/$file /usr/local/nagios/etc/nagios.cfg > /dev/null ; then
			:
		else
			echo "$file added to nagios.cfg"
			echo "cfg_file=$CONFIG_DIR/$file" >> /usr/local/nagios/etc/nagios.cfg
		fi
	fi
done


# Install the new config files
ls $TEMPDIR
if cp $TEMPDIR/*.cfg $CONFIG_DIR
then

	# If the new file is bad, reinstall the old file
	if $NAGIOS_BIN -v $NAGIOS_CFG > /dev/null 
	then
		echo "Config OK"
		if [ $DEBUG -eq 0 ]; then
			rm -rf $TEMPDIR
		fi
		exit 0
	else
		echo "Config broken"
		$NAGIOS_BIN -v $NAGIOS_CFG
		cp $TEMPDIR/oldconfigs/*.cfg $CONFIG_DIR
		if [ $DEBUG -eq 0 ]; then
			rm -rf $TEMPDIR
			echo 
		fi
		exit 1
	fi
else
	echo "No valid config"
	cp $TEMPDIR/oldconfigs/*.cfg $CONFIG_DIR
fi

if [ -d $TEMPDIR ]; then
 rm -rf $TEMPDIR
fi
