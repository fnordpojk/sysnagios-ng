#!/bin/sh

urlencode(){
	 echo $1 | perl -MURI::Escape -lane 'print uri_escape($F[0]);' | perl -MURI::Escape -lane 'print uri_escape($F[0]);'
}

urldecode(){
	echo $1 | perl -MURI::Escape -lane 'print uri_unescape($F[0]);' | perl -MURI::Escape -lane 'print uri_unescape($F[0]);'
}

rollback(){
	echo "Rolling back changes"
	curl -s -k -X DELETE -u $SYSNAGIOS_USER:$SYSNAGIOS_PASSWD https://$API_SERVER/api/config/change 
	rollback_rollback=yes
	echo " "
	exit 1
}


save(){
	if [ -z "$rollback_rollback" ]; then 
		echo "SAVING"
		curl -d "" -s -k -u $SYSNAGIOS_USER:$SYSNAGIOS_PASSWD https://$API_SERVER/api/config/change > /dev/null 2>&1
	fi
}

check_host_exist(){
	che_hostname=$1
	curl -s -k -u $SYSNAGIOS_USER:$SYSNAGIOS_PASSWD https://$API_SERVER/api/config/host/$che_hostname  | grep -v "Object not found" > /dev/null 2>&1
	che_tmp=$?
	return $che_tmp
}

delete_global_services(){
	for dgs_service in $global_services; do
		dgs_tmp_service=`urldecode $dgs_service`
		echo DELETE \"$dgs_tmp_service\"
		dgs_curl_res=`curl -X DELETE -s -k -u $SYSNAGIOS_USER:$SYSNAGIOS_PASSWD https://$API_SERVER/api/config/service/$HOST%253B$dgs_service`
		if echo $dgs_curl_res|grep error: > /dev/null; then
			echo "Delete $dgs_service failed"
			echo $dgs_curl_res
			rollback
		fi
	done
}

get_services(){
	gs_hostname=$1


	gs_global_services=`curl -s -k -u $SYSNAGIOS_USER:$SYSNAGIOS_PASSWD https://$API_SERVER/api/config/host/$gs_hostname?format=xml | grep service_description | sed 's/<[^>]\+>//g' | sed 's/^ *//' |  sort | xargs echo`

	global_services=""
	for gs_c in $gs_global_services; do
		gs_c=`urlencode $gs_c`
		global_services="$global_services $gs_c"
	done
}

pop_service (){
	#ps_service=`echo $1|  perl -MURI::Escape -lane 'print uri_escape($F[0]);' `
	ps_service=`urlencode $1`
	global_services=`echo " " $global_services " "| sed "s/ $ps_service / /g"`
} 

check_service_exist(){
	cse_hostname=$1
	cse_service=$2
	cse_service=`urlencode $cse_service`
	
	echo " " $global_services " " |  grep " $cse_service " > /dev/null 2>&1
	che_tmp=$?
	return $che_tmp
}

# get commandlist for current host
make_array(){
	# make the comma list into a space-list
	ma_list=`echo "$1" | sed 's/ //g' | sed 's/,/ /g'`
	ma_outstr='['
	for ma_loop in $ma_list; do 
		ma_outstr=$ma_outstr'"'$ma_loop'",'
	done
	ma_outstr=`echo $ma_outstr | sed 's/.$//'`']'
	echo $ma_outstr
}

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

	ws_hostname=$1
	ws_service=$2
	ws_contactgroups=$3
	ws_notification_period=$4
	ws_check_command=$5

	#if [ $ws_service = "disk_/opt/apps" ];then set -x; fi
	ws_outfile=/tmp/${ws_hostname}_service.$$.cfg

	if check_service_exist $ws_hostname $ws_service; then 
		echo "Service $ws_service is already configured - patching"
		ws_patching=1
		ws_patcharg="-X PATCH"
		ws_service_encoded=`urlencode $ws_service`
		ws_patchobj="/$ws_hostname%253B$ws_service_encoded"
	else
		echo "Service $ws_service is not configured - creating"
		ws_patching=0
		ws_patchobj=""
		ws_patcharg=""
	fi


	ws_outstr='{"template":"'$SERVICE_TEMPLATE\"
	ws_outstr=$ws_outstr',"host_name":"'$ws_hostname\"
	ws_outstr=$ws_outstr',"service_description":"'$ws_service\"

	if [ -n "$ws_contactgroups" ]; then
		ws_outstr=$ws_outstr',"contact_groups":'`make_array $ws_contactgroups`
	fi
	if [ -n "$ws_notification_period" ]; then
		ws_outstr=$ws_outstr',"notification_period":"'$ws_notification_period\"
	fi
	ws_outstr=$ws_outstr',"_PORT":"'$NRPE_PORT\"
	ws_outstr=$ws_outstr',"_ARG":"'$NRPE_ARGS' "'
	ws_outstr=$ws_outstr',"register":"1"'

	ws_outstr=$ws_outstr',"notes":"'$NOTES\"
	ws_outstr=$ws_outstr',"action_url":"'$action_url\"

	if [ -n "$SERVICEGROUPS" ] ; then
		ws_outstr=$ws_outstr',"servicegroups":"'`make_array $SERVICEGROUPS`\"
	fi

	ws_outstr=$ws_outstr',"check_command":"'$check_command\"
	ws_outstr=$ws_outstr',"check_command_args":"'$check_command_args\"

	if [ -n "$max_check_attempts" ] ; then
		ws_outstr=$ws_outstr',"max_check_attempts":"'$max_check_attempts\"
	fi

	if [ -n "$CHECK_PERIOD" ] ; then
		ws_outstr=$ws_outstr',"check_period":"'$CHECK_PERIOD\"
	fi

	if [ -n "$SVARS" ]; then 
		for var in $SVARS; do
			val=""
			eval `printf 'val=$svar_%s' "$var"`
			ws_outstr=$ws_outstr`printf ',"_%s":"%s"' "$var" "$val"`
		done
	fi

	ws_outstr=$ws_outstr'}'
	echo $ws_outstr >> $ws_outfile

	ws_curl_output=`curl $ws_patcharg -s -k -H 'content-type: application/json' -u $SYSNAGIOS_USER:$SYSNAGIOS_PASSWD https://$API_SERVER/api/config/service$ws_patchobj -d \@$ws_outfile`  

	#if [ $ws_service != "disk_/home" ];then 
	rm $ws_outfile
	#fi

	if echo $ws_curl_output | grep '{"error":' > /dev/null ; then
		echo "ERROR in service"
		echo $ws_curl_output
		rollback
	fi
	#set +x
}

write_host() {
	# fixa hosts_template
	# $1 - HOST
	# $2 - ALIAS
	# $3 - CONTACT
	# $4 - SLA
	# $5 - IP
	wh_hostname=$1

	debug "write_host XXX $1 $2 $3 $4 $5"

	if check_host_exist $wh_hostname; then 
		echo "Host $wh_hostname is already configured - patching"
		wh_patching=1
	else
		echo "Host $wh_hostname is not configured - creating"
		wh_patching=0
	fi


	write_host_outfile=/tmp/$wh_hostname.host.$$.json

	debug "write_host_outfile=$write_host_outfile"

	if [ -f "$write_host_outfile" ];then
		rm $write_host_outfile
	fi

	debug "write_host write_host_outfile=${write_host_outfile}"

	if [ -z "$2" ]; then 
		write_host_alias=$wh_hostname
	else
		write_host_alias=$2
	fi

	w_h_host_template="$HOST_TEMPLATE"
	if [ -n "$HOST_APPEND_TEMPLATE" ]; then
		w_h_host_template="$w_h_host_template$HOST_APPEND_TEMPLATE"
	fi

	w_h_outstr='{"template":"'$w_h_host_template'"'
	w_h_outstr=$w_h_outstr',"host_name":"'$wh_hostname'"'
	w_h_outstr=$w_h_outstr',"alias":"'$write_host_alias'"'
	w_h_outstr=$w_h_outstr',"display_name":"'$write_host_alias'"'
	w_h_outstr=$w_h_outstr',"register":"1"' 

	w_h_outstr=$w_h_outstr',"notes":"'$NOTES'"'
	w_h_outstr=$w_h_outstr',"action_url":"'$action_url'"'

	if [ -n "$4" ]; then
		 w_h_outstr=$w_h_outstr',"notification_period":"'$4'"' 
	fi

	w_h_outstr=$w_h_outstr',"address":"'$5'"'
	w_h_outstr=$w_h_outstr',"_PORT":"'$NRPE_PORT' "'
	w_h_outstr=$w_h_outstr',"_ARG":"'$NRPE_ARGS' "'
	w_h_outstr=$w_h_outstr',"_SSL":"'$SSL' "'

	if [ -n "$CHECK_PERIOD" ]; then
		w_h_outstr=$w_h_outstr',"check_period":"'$CHECK_PERIOD'"'
	fi

	if [ -n "$HOSTGROUP" ] ; then
		w_h_hostgroups=$HOSTGROUP

		if [ -n "$HOSTGROUP_APPEND" ]; then
			w_h_hostgroups=$HOSTGROUP,$HOSTGROUP_APPEND
		fi

		w_h_outstr=$w_h_outstr',"hostgroups":'`make_array $w_h_hostgroups`
	fi

	#Contactgroups
	if [ -n "$3" ]; then 
		w_h_outstr=$w_h_outstr',"contact_groups":'`make_array $3`
	fi 


	if [ -n "$max_check_attempts" ] ; then
		w_h_outstr=$w_h_outstr',"max_check_attempts":"'$max_check_attempts'"'
	fi

	if [ -n "$HVARS" ]; then 
		for var in $HVARS; do
			val=""
			eval `printf 'val=$hvar_%s' "$var"`
			w_h_outstr=$w_h_outstr','`printf '"_%s":"%s"' "$var" "$val"`
		done
	fi
		
	w_h_outstr=$w_h_outstr'}'

	echo $w_h_outstr > $write_host_outfile

	wc_patchobj=""
	if [ $wh_patching = 1 ]; then
		wh_patcharg="-X PATCH"
		wh_patchobj=/$wh_hostname
	else
		echo "CREATING HOST $wh_hostname"
	fi

	wh_curl_output=`curl $wh_patcharg -s -H 'content-type: application/json' -d '@'$write_host_outfile  https://$API_SERVER/api/config/host$wh_patchobj -u $SYSNAGIOS_USER:$SYSNAGIOS_PASSWD -k`
	
	#echo $wh_curl_output
	rm $write_host_outfile

	if echo  $wh_curl_output | grep '{"error":' > /dev/null ; then
		echo $wh_curl_output
		rollback
		exit
	fi
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

