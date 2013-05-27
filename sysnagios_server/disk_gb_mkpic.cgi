#!/bin/sh
DEBUG=0
RRDDIR=/usr/local/nagios/rrd
RRDTOOL=/usr/local/bin/rrdtool

debug() {
	if [ $DEBUG = 1 ] ; then
		echo "$1"
	fi
}

debug "Cache-Control: no-store"
debug "Pragma: no-cache"
debug "Refresh: 90"
debug "Last-Modified: $MDATE"
debug "Expires: Thu, 01 Jan 1970 00:00:00 GMT"
debug "Content-type: text/html"
debug ""
debug "<TITLE>TJOSAN</TITLE><H1>DEBUG</H1><P>"

# Strip from / to prevent url propagation
QUERY_STRING=`echo "$QUERY_STRING" | sed -n '{s/[/]//g;p}'`


IMGTYPE="PNG"
# Generate a valid header
case $IMGTYPE in
	PNG) echo "Content-type: image/png"
	;;
	GIF) echo "Content-type: image/gif"
	;;
	GD ) echo "Content-type: image/gd"
	;;
esac
echo ""

# Get the params from the URL
RRDFILE=`echo $QUERY_STRING|cut -d "&" -f 1 | cut -d "=" -f 2`
TIME=`echo $QUERY_STRING|cut -d "&" -f 2 | cut -d "=" -f 2`
WIDTH=`echo $QUERY_STRING|cut -d "&" -f 3 | cut -d "=" -f 2`
HEIGTH=`echo $QUERY_STRING|cut -d "&" -f 4 | cut -d "=" -f 2`
debug "QS: $QUERY_STRING<P>"
debug "TIME=$TIME, WIDTH=$WIDTH, HEIGTH=$HEIGTH <P>"
debug "<BR>sysnagios_mkpic.cgi rrdfile=$RRDFILE Width: $WIDTH, Height: $HEIGTH<BR>"

if [ "$WIDTH" = "" ] || [ "$HEIGTH" = "" ]; then
	WIDTH=640
	HEIGTH=100
fi


	#ARG="$ARG DEF:var$N=$RRDFILE:$DSNAME:AVERAGE $TYPE:var${N}$COL:$DSNAME:"

# Generate the image
# /usr/local/bin/rrdtool graph - -s -600 -a PNG -v % -w 640 -h 100  -l 0 -u 100 --rigid  DEF:var0=/usr/local/nagios/rrd/bastard1_disk_usage_check_disk_home.rrd:check_disk_home:AVERAGE LINE2:var0#ff0000:check_disk_home:

$RRDTOOL graph - --font DEFAULT:0:/usr/share/fonts/bitstream-vera/VeraSe.ttf -s -$TIME -a $IMGTYPE -v Gb -w $WIDTH -h $HEIGTH  DEF:var0=$RRDDIR/$RRDFILE:Used:AVERAGE LINE2:var0#ff0000:"Gb Used"

