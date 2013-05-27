#!/bin/sh

DEBUG=1 
WIDTH=500
HEIGHT=75

debug() {
	if [ $DEBUG ] ; then
		echo "$1"
	fi
}

#Security measurement. Prevent URL mangling
QUERY_STRING= `echo $QUERY_STRING|sed -n '{s/[./]//g;s/\///g;p}'`

HOST=`echo $QUERY_STRING|cut -d "&" -f 1|cut -d "=" -f 2`
SERVICE=`echo $QUERY_STRING|cut -d "&" -f 2|cut -d "=" -f 2`
PLUGIN=`echo $QUERY_STRING|cut -d "&" -f 3|cut -d "=" -f 2`
#HEIGHT=`echo $QUERY_STRING|cut -d "&" -f 4|cut -d "=" -f 2`
RRDFILE="${HOST}_${PLUGIN}_${SERVICE}.rrd"
RRDDIR="/usr/local/nagios/rrd/"

#Genereta a header
echo "Cache-Control: no-store"
echo "Pragma: no-cache"
echo "Refresh: 90"
echo "Last-Modified: $MDATE"
echo "Expires: Thu, 01 Jan 1970 00:00:00 GMT"
echo "Content-type: text/html"
echo ""

debug "<HTML><HEAD><TITLE>$LABEL for host $HOST</TITLE>"

debug "QUERY_STRING=$QUERY_STRING <BR>"
debug  "RRDFILE: $RRDFILE <BR>"
debug "$HOST"

echo "<LINK REL='stylesheet' TYPE='text/css' HREF='/nagios/stylesheets/status.css'></head><BODY>"

if [ ! -r $RRDDIR/$RRDFILE ]; then
	cgidebug "RRD-file does not exist or is not readable ($RRDFILE)"
	echo "<H3>RRD-file does not exist or is not readable</H3>"
	echo "<PRE>($RRDFILE).</PRE>"
	echo "<A HREF=javascript:history.go(-1)>Back</A>"
	echo "</BODY></HTML>"
	exit
fi
N=0
if [ "$PVERS" != "1" ]; then
	echo "<TABLE CLASS='infoBox' BORDER=1 CELLSPACING=0 CELLPADDING=0>"
	echo "<TR><TD CLASS='infoBox'>"
	echo "<DIV CLASS='infoBoxTitle'>Sysnagios-graphs</DIV>"
	echo "Genereated by Sysnagios - <A HREF='http://apan.sf.net' TARGET=_new CLASS='homepageURL'>apan.sf.net</A><BR>"
	echo "Last Updated: $MDATE<BR>"
	echo "Updated every 90 seconds<br>"
	echo "Nagios&reg; - <A HREF='http://www.nagios.org' TARGET='_new' CLASS='homepageURL'>www.nagios.org</A><BR>"
	echo "Logged in as <i>$REMOTE_USER</i><BR>"
	echo "</TD></TR>"
	echo "</TABLE>"
	echo "<A HREF=javascript:history.go(-1)>Back</A>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
	echo "<A HREF=/nagios/cgi-bin/apan-sql.cgi?${QUERY_STRING}&1 TARGET=_blank>Print</A>"
fi
echo "<H2>$LABEL ($SERVICE) for host $HOST</H2>"

#Draw 'compressed' graphs if this is for printing

		echo "Statistics for the last 10 minutes:<BR>"
		echo  "<IMG SRC=sysnagios_mkpic.cgi?rrd=//$RRDFILE&timespan=600&width=$WIDTH&height=$HEIGHT ><BR>"

		echo "Statistics for the last hour:<BR>"
		echo  "<IMG SRC=sysnagios_mkpic.cgi?rrd=//$RRDFILE&timespan=3600&width=$WIDTH&height=$HEIGHT ><BR>"

		echo "Statistics for the last 24 hours:<BR>"
		echo  "<IMG SRC=sysnagios_mkpic.cgi?rrd=//$RRDFILE&timespan=86400&width=$WIDTH&height=$HEIGHT ><BR>"
		echo "Statistics for the last week:<BR>"
		echo  "<IMG SRC=sysnagios_mkpic.cgi?rrd=//$RRDFILE&timespan=604800&width=$WIDTH&height=$HEIGHT ><BR>"
		echo "Statistics for the last Month:<BR>"
		echo  "<IMG SRC=sysnagios_mkpic.cgi?rrd=//$RRDFILE&timespan=2851200&width=$WIDTH&height=$HEIGHT ><BR>"
		echo "Statistics for the last Year:<BR>"
		echo  "<IMG SRC=sysnagios_mkpic.cgi?rrd=//$RRDFILE&timespan=31557600&width=$WIDTH&height=$HEIGHT ><BR>"

echo "</BODY></HTML>"
