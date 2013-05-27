#!/bin/sh
EXTINFOFILE=/usr/local/nagios/etc/nagiosgraph_auto_extinfo.cfg

if [ -f $EXTINFOFILE ]
then
	rm $EXTINFOFILE 
fi

cd /usr/local/nagios/rrd_nagiosgraph

for host in `ls -l | egrep '^d' | awk '{print $9}'`
do
	echo $host
	if [ "$host" != "sdcutv50" ] ; then
	cat >> $EXTINFOFILE << EOF

define hostextinfo {
	use nagiosgraph-host
	host_name         $host
	notes					Download new configuration
	notes_url        /nagios/cgi-bin/nagiosgraph/show.cgi?host=$host
	action_url			/nagios/cgi-bin/getconfigs.cgi?host=$host
	register          1
	icon_image_alt  View graphs
	}

EOF
	fi

done
