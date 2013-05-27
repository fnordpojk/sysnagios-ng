#!/bin/sh

# get commandlist for current host
iscommand() {
	debug "iscommand command: $1 host: $2"
	iscommand_arg=$1
	iscommand_retval=0

	iscommand_expression="sed -n '/^#::host_start $2/,/^#::host_end$/{;/^#/d;/^$/d;s/]/ /;s/\[/ /;/^command/p;}' $TMP_CONFIG_FILE | $AWK '{print \$2}'"
	#echo "$iscommand_expression"
	#echo `eval $iscommand_expression`

	for line in `eval $iscommand_expression` ; do
		if [ $line = $iscommand_arg ]; then
			return 1;
		fi
	done
	return 0
}

# Set variable $monkey to 1 if the check $1 is a monkey
# Set variable $plugin to the corresponding plugin name
ismonkey() {
	debug "ismonkey check: $1 host: $2"
	ismonkey_monkey=0

	# get monkeylist for current host
 	ismonkey_expression="sed -n '/^#::host_start $2/,/^#::host_end$/{;s/^# +/#/;/^$/d;/^#::.*apan /p;}' $TMP_CONFIG_FILE | sed 's/#:://' | $AWK '{print \$3}'"
	debug "$ismonkey_expression"
	debug "monkeys: `eval $ismonkey_expression`"

 	for line in `eval $ismonkey_expression` ; do
		if  [ $line = $1 ]; then
			ismonkey_monkey=1;
			plugin=`grep $1 $TMP_CONFIG_FILE | $AWK  '/#::apan/ { print $2 }' | sed -n '1p'`
			return $ismonkey_monkey
		fi
	done
	return $ismonkey_monkey
}

debug() {
	if [ $DEBUG -gt 0 ] 
	then
		echo 	$1
	fi
}

get_ip() {
	debug "get_ip $1"
	get_ip_host=$1
	if grep $get_ip_host /etc/hosts > /dev/null; then
		debug "Getting IP from /etc/hosts"
		#ip=`grep $get_ip_host /etc/hosts | tr -s '\011' '\040' | sed -n "/^#/d; / ${1} /p;/ ${1}$/p" | $AWK '{ print $1 }' | head -1`
		ip=` grep $get_ip_host /etc/hosts | $AWK '{ print $1 }' | head -1`
	else
		debug "Getting IP from nslookup"
		ip=`nslookup $1 | eval "sed -n '/$get_ip_host/,\\$p'" | awk '/Address:/{print $2}'`
		debug "IP: $ip"
	fi
}

write_services() {
	debug "write_services .$1.$2.$3.$4.$5."
	# var1=hostname
	# var2=check
	# var3=contact
	# var4=sla
	# var5=check_command
	# Finns en services_conf redan? Då kollas om det finns kontaktinfo redan

	write_services_outfile=$write_host_outfile
	debug "write_services_outfile=$write_services_outfile"
	debug "write_services write_services_outfile=${write_services_outfile}"

	echo "define service {" >> $write_services_outfile
	echo "	use                             $SERVICE_TEMPLATE" >> $write_services_outfile
	echo "	host_name                       $1" >> $write_services_outfile
	echo "	service_description             $2" >> $write_services_outfile
	if [ -n "$3" ]; then
		echo "	contact_groups                  $3" >> $write_services_outfile
	fi
	if [ -n "$4" ]; then
		echo "	notification_period             $4" >> $write_services_outfile
	fi
	#echo "	check_command                   $5" >> $write_services_outfile
	echo "	_PORT                           $NRPE_PORT" >> $write_services_outfile
	echo "	_ARG                            $NRPE_ARGS" >> $write_services_outfile
	echo "	register                        1" >> $write_services_outfile

	if [ -n "$SERVICEGROUPS" ] ; then
		echo "	servicegroups               $SERVICEGROUPS" >> $write_services_outfile
	fi

	if [ -n "$max_check_attempts" ] ; then
		echo "	max_check_attempts          $max_check_attempts" >> $write_services_outfile
	fi
	if [ -n "$CHECK_PERIOD" ] ; then
		echo "	check_period          $CHECK_PERIOD" >> $write_services_outfile
	fi

	if [ -n "$SVARS" ]; then 
		for var in $SVARS; do
			val=""
			eval `printf 'val=$svar_%s' "$var"`
			printf '	_%s          %s\n' "$var" "$val" >> $write_host_outfile
		done
	fi

	echo "}" >> $write_services_outfile
}

write_hostextinfo () {
	# $1 host
	# $2 notes
	# $3 ip
	debug "write_hostextinfo $1 $2 $3"

	write_hostextinfo_outfile=`mkfilename $1`

	echo "define hostextinfo  {   " >> $write_hostextinfo_outfile
	echo "	use                   $HOST_EXTINFO_TEMPLATE" >> $write_hostextinfo_outfile
	echo "	host_name             $1" >> $write_hostextinfo_outfile

	if [ -n "$HOST_EXTINFO_ACTION_URL" ]; then 
		echo "	action_url             $HOST_EXTINFO_ACTION_URL$SSL_URL" >> $write_hostextinfo_outfile
	fi
	if [ -n "$HOST_EXTINFO_NOTES_URL" ]; then 
		echo "	notes_url             $HOST_EXTINFO_NOTES_URL" >> $write_hostextinfo_outfile
	fi
	if [ -n "$2" ]; then
		echo "	notes $2" >> $write_hostextinfo_outfile
	fi
	echo "}   "                        >> $write_hostextinfo_outfile
}

write_servicextinfo () {
	# $1 host
	# $2 service_description
	# $3 notes
	debug "write_servicextinfo $1 $2 $3"

	#write_servicextinfo_outfile=`mkfilename $1`
	write_servicextinfo_outfile=$write_host_outfile

	echo "define serviceextinfo  {   " >> $write_servicextinfo_outfile
	echo "	use                   $SERVICE_EXTINFO_TEMPLATE" >> $write_servicextinfo_outfile
	echo "	host_name             $1" >> $write_servicextinfo_outfile
	echo "	service_description   $2" >> $write_servicextinfo_outfile

	if [ -n "$SERVICE_EXTINFO_ACTION_URL" ]; then 
		echo "	action_url             $SERVICE_EXTINFO_ACTION_URL" >> $write_servicextinfo_outfile
	fi
	if [ -n "$SERVICE_EXTINFO_NOTES_URL" ]; then 
		echo "	notes_url             $SERVICE_EXTINFO_NOTES_URL" >> $write_servicextinfo_outfile
	fi
	if [ -n "$3" ]; then
		echo "	notes $3" >> $write_servicextinfo_outfile
	fi
	echo "}   "                        >> $write_servicextinfo_outfile
}

write_host() {
	# fixa hosts_template
	# $1 - HOST
	# $2 - ALIAS
	# $3 - CONTACT
	# $4 - SLA
	# $5 - IP

	debug "write_host XXX $1 $2 $3 $4 $5"

	write_host_outfile=`mkfilename $1`
	debug "write_host_outfile=$write_host_outfile"

	if [ -f "$write_host_outfile" ];then
		rm $write_host_outfile
	fi

	debug "write_host write_host_outfile=${write_host_outfile}"

	if [ -z "$2" ]; then 
		write_host_alias=$1
	else
		write_host_alias=$2
	fi

	echo "define host{" >> $write_host_outfile
	echo "	use                   $HOST_TEMPLATE" >> $write_host_outfile
	echo "	host_name             $1" >> $write_host_outfile
	echo "	alias                 $write_host_alias" >> $write_host_outfile
	echo "	display_name          $write_host_alias" >> $write_host_outfile
	echo "	register              1" >> $write_host_outfile
	
	if [ -n "$3" ]; then 
		echo "	contact_groups        $3" >> $write_host_outfile
	fi 

	if [ -n "$4" ]; then
		echo "	notification_period   $4" >> $write_host_outfile
	fi

	echo "	address               $5" >> $write_host_outfile
	echo "	_PORT                 $NRPE_PORT" >> $write_host_outfile
	echo "	_ARG                  $NRPE_ARGS" >> $write_host_outfile
	echo "	_SSL                  $SSL" >> $write_host_outfile

	if [ -n "$CHECK_PERIOD" ]; then
		echo "	check_period          $CHECK_PERIOD" >> $write_host_outfile
	fi

	if [ -n "$HOSTGROUP" ] ; then
		echo "	hostgroups               $HOSTGROUP" >> $write_host_outfile
	fi

	if [ -n "$max_check_attempts" ] ; then
		echo "	max_check_attempts               $max_check_attempts" >> $write_host_outfile
	fi

	if [ -n "$HVARS" ]; then 
		for var in $HVARS; do
			val=""
			eval `printf 'val=$hvar_%s' "$var"`
			printf '	_%s               %s\n' "$var" "$val" >> $write_host_outfile
		done
	fi
		
	echo "}" >> $write_host_outfile
}


clean() {
	debug "Alla configurationsfiler borttagna"
	#rm -rf $TMPDIR
}


# Makes a filename
mkfilename() {
# $1 = hostname
	echo "$TEMPDIR/${1}_services.cfg"
}

