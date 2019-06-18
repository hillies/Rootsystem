#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin


###############################
# -----------------------------
#	Updated 21 Feb 2019
#	Quintin Hills
#	V.3
# -----------------------------
###############################
# Note: Ping any server
# V.2 Less notifications
# V.3 Pretest option and option to Flush Logfile



#################################
#############	VARIABLES PART 1
#################################
HOSTNAME=$(hostname -s)

### Log Discription
# -----------------
COMPANY="Company"
DISCRIPTION="Ping Test"

### Slack Channel
# ---------------
CHANNEL="alert"

### IP to test pings
# ------------------
IP=0.0.0.0

### Pretest ping [ y/n ]
# ----------------------
PRETEST=n
PRETESTCOUNT=1

### How many pings
# ----------------
COUNT=10

### OK State - if packet loss is less that (x)%
# ---------------------------------------------
OKSTATE=5

### PACKETLOSS State - if packet loss is greater that (x)%
# --------------------------------------------------------
PLSTATE=20

### Delete Logfile after each run
# -------------------------------
FLUSHLOGFILE=n



#################################
#############	VARIABLES PART 2
#################################

### Directories
# -------------
MAINDIR=/usr/local/qrs/iperfping
LOGDIR=/var/log
TMPDIR=/tmp

### Node Config
### NOTE: nodename = filename for logfile and tempfiles
# -----------------------------------------------------
filename=$(basename "$0" | sed 's/.\{3\}$//')
nodename=$filename

### Log
# -----
LOGFILE="$LOGDIR/$nodename.log"
LSIZE=1008



#################################################
############# MAIN LOG FILE (CREATE AND TRIM LOG)
#################################################

### check if it exist if not create log file
# -------------------------------------------
if [ -f $LOGFILE ]
then
	:
else
   touch $LOGFILE
fi

## Line Count (Keeps last X lines in logfile)
# --------------------------------------------
LINECOUNT="$(cat $LOGFILE | wc -l | tr -d ' ')"
if [ $LINECOUNT -eq $LSIZE ]
then
	tail -n +2 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
fi



######################################
############# TEMP LOGS FILE (CREATE)
######################################

### check if it exist if not create log file
# -------------------------------------------
for tmplog in status statuscount
do
	if [ -f $TMPDIR/.$tmplog"_"$nodename.tmp ]
	then
        	:
	else
   		touch $TMPDIR/.$tmplog"_"$nodename.tmp
   		echo 0 > $TMPDIR/.$tmplog"_"$nodename.tmp
	fi
done



###########################################
#############	RECORD START TIME AND DATE
###########################################

DATE="$(date +%h' '%d)"
TS="$(date +%H:%M:%S)"



#############################
#############	PING TEST
#############################

### PRE TEST
# ----------
if [ $PRETEST = y ]
then
	ping $IP -c $PRETESTCOUNT > /dev/null 2>&1
	error=$? 						# 0=OK, 1=FAIL
else
	error=0
fi

if [ $error -eq 0 ]
then
	### ACTUAL TEST
	# -------------
	ping $IP -c $COUNT > $TMPDIR/.ping$nodename.tmp 2> /dev/null
	UNT10="$(cat $TMPDIR/.ping$nodename.tmp | grep packet | awk 'match($0,"%"){print substr($0,RSTART-6)}' | cut -d' ' -f2- |  sed 's/%.*//')"
	UNT11="$(printf "%.0f" $UNT10)"
	UNT20="$(cat $TMPDIR/.ping$nodename.tmp | grep avg | awk -F'[/]' '{print $5}')"
	UNT21="$(printf "%.0f" $UNT20)"

	if [ $UNT11 -le $OKSTATE ]
	then
		STATE=OK
		echo 0 > $TMPDIR/.status$nodename.tmp
	elif [ $UNT11 -eq 100 ]
	then
		STATE=DOWN
		echo 1 > $TMPDIR/.status$nodename.tmp
	elif [ $UNT11 -gt &PLSTATE ]
	then
		STATE=PACKETLOSS
		echo 1 > $TMPDIR/.status$nodename.tmp
	fi
else
	STATE="PRE TEST FAIL"
	UNT11="100"
	UNT21="0"
	echo 1 > $TMPDIR/.status$nodename.tmp
fi
teststatus=$(cat $TMPDIR/.status$nodename.tmp)

###  PREVIOUS STATUS COUNT
# ------------------------
if [ ! -f $TMPDIR/.statuscount$nodename.tmp ]
then 
	echo 0 >> $TMPDIR/.statuscount$nodename.tmp
fi

previousteststatus=$(cat $TMPDIR/.statuscount$nodename.tmp | wc -l)

###  STATUS COUNTING
# ------------------
if [ $teststatus -eq 1 ]
then
	echo 1 >> $TMPDIR/.statuscount$nodename.tmp
else
	### CLEAR STATUS COUNTER
	# ----------------------
	rm -f $TMPDIR/.statuscount$nodename.tmp
	touch $TMPDIR/.statuscount$nodename.tmp
fi

###  CURRENT STATUS COUNT
# -----------------------
currentteststatus=$(cat $TMPDIR/.statuscount$nodename.tmp | wc -l)

### ALERTS
# --------
if [ $currentteststatus -eq 2 ] 		# 10min 2nd FAIL
then
	$MAINDIR/bin/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "1: $DISCRIPTION $IP on $HOSTNAME" "#ff0000" "pl: $UNT11%" "avg: $UNT21""ms"
elif [ $currentteststatus -eq 6 ]		# 30min 6th FAIL
then
	$MAINDIR/bin/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "2: $DISCRIPTION $IP on $HOSTNAME" "#ff0000" "pl: $UNT11%" "avg: $UNT21""ms"
elif [ $currentteststatus -eq 12 ]		# 1hour 12th FAIL
then
	$MAINDIR/bin/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "3: $DISCRIPTION $IP on $HOSTNAME" "#ff0000" "pl: $UNT11%" "avg: $UNT21""ms"
elif [ $currentteststatus -eq 24 ]		# 2hours 24th FAIL
then
	$MAINDIR/bin/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "4: $DISCRIPTION $IP on $HOSTNAME" "#ff0000" "pl: $UNT11%" "avg: $UNT21""ms"
elif [ $currentteststatus -eq 36 ]		# 3hours 36th FAIL
then
	$MAINDIR/bin/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "5: $DISCRIPTION $IP on $HOSTNAME" "#ff0000" "pl: $UNT11%" "avg: $UNT21""ms"
fi

if [ $previousteststatus -ge 2 ]
then
	if [ $currentteststatus -eq 0 ]
	then 
		STATE=RECOVERED
		$MAINDIR/bin/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "$DISCRIPTION $IP on $HOSTNAME" "#009b1f" "pl: $UNT11%" "avg: $UNT21""ms"
	fi
fi



###########################################
#############	RECORD END TIME AND DATE
###########################################

TE="$(date +%H:%M:%S)"



#######################
#############  LOGGING
#######################

### To MYSQL
# ---------- 
#sqldate="$(date +%y%m%d%H%M%S)"
#php $MAINDIR/data/mysql/insert.php $sqldate $DISCRIPTION $STATE $UNT11 $UNT21 $SUM

### To local Logfile
# ------------------
echo "$DATE $TS - $TE, company=$COMPANY, discription=$DISCRIPTION, state=$STATE, packetloss(%)=$UNT11, avg(ms)=$UNT21" >> $LOGFILE

if [ $FLUSHLOGFILE = y ]
then
	rm -f $LOGFILE
fi