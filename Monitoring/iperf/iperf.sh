#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin


###############################
# -----------------------------
#	Updated 21 Feb 2019
#	Quintin Hills
#	V.2.1
# -----------------------------
###############################
# Note: Iperf test to any Iperf3 server
# V.2 Less notifications



#################################
#############    VARIABLES PART 1
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



#################################
#############	VARIABLES PART 2
#################################

### Log Discription
# -----------------
COMPANY="Company"
DISCRIPTION="Iperf Test"

### Slack Channel
# ---------------
CHANNEL="alert"

### Iperf Server
# --------------
IP=0.0.0.0					

### Iperf Server Port [ default 5201 ]
# ------------------------------------
PORT=5201					

### Max Linespeed Mbps (Mega bits per second)
# -------------------------------------------
LINESPEED=50		



##################################################
############# MAIN LOG FILE (CREATE AND TRIM LOG)
##################################################

### Check if it exist if not create log file
# ------------------------------------------
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
# ------------------------------------------
for templogs in p1 p1s1 p1s2 p2 p2s3 p2s4 p2s5
do
	if [ -f $TMPDIR/.$templogs""$nodename.tmp ]
	then
		:
	else
		echo 0 > $TMPDIR/.$templogs""$nodename.tmp		# default OK state (0 = OK)
	fi
done



###########################################
#############	RECORD START TIME AND DATE
###########################################

DATE="$(date +%h' '%d)"
TS="$(date +%H:%M:%S)"



##################################
#############	IPERF TEST PART 1
##################################

### PING TEST
# -----------
ping $IP -c 1 > /dev/null 2>&1
if [ $? -eq 0 ]
then    
	### TELNET TEST
	# -------------
	telnetres=$(echo exit | telnet $IP $PORT 2> /dev/null | wc -m)
	if [ $telnetres -eq 73 ]
	then
		### PING and TELNET FINE (ACTUAL TEST) 		status 0
		# ------------------------------------
		iperf3 -c $IP -p $PORT > $TMPDIR/.iperf$nodename.tmp
		SENX="$(cat $TMPDIR/.iperf$nodename.tmp | grep sender | awk '{print $7}')"
		SEN="$(printf "%.0f" $SENX)"
		RECX="$(cat $TMPDIR/.iperf$nodename.tmp | grep receiver | awk '{print $7}')"
		REC="$(printf "%.0f" $RECX)"
		SUMX=$(($SEN + $REC))
		SUM=$(($SUMX / 2))
		echo 0 > $TMPDIR/.p1$nodename.tmp
		STATE=OK
	else
		### TELNET FAIL					status 1
		# -------------
		SUM="IPERF NOT RUNNING ON REMOTE SERVER"
		STATE=WARNING
		echo 1 > $TMPDIR/.p1$nodename.tmp
	fi
else
	### PING FAIL 						status 2
	# -----------
	SUM="IPERF SERVER UNAVAILABLE"
	STATE=WARNING
	echo 2 > $TMPDIR/.p1$nodename.tmp
fi

p1=$(cat $TMPDIR/.p1$nodename.tmp)

### RECORD BEFORE STATUS
# ----------------------
p1s1before=$(cat $TMPDIR/.p1s1$nodename.tmp | wc -l)
p1s2before=$(cat $TMPDIR/.p1s2$nodename.tmp | wc -l)

### STATUS COUNTING
# -----------------
if [ $p1 -eq 1 ]
then 
	echo 1 >> $TMPDIR/.p1s1$nodename.tmp
elif [ $p1 -eq 2 ]
then
	echo 2 >> $TMPDIR/.p1s2$nodename.tmp
elif [ $p1 -eq 0 ]
then
	### CLEAR STATUS
	# --------------
	rm -f $TMPDIR/.p1s1$nodename.tmp ; touch $TMPDIR/.p1s1$nodename.tmp
	rm -f $TMPDIR/.p1s2$nodename.tmp ; touch $TMPDIR/.p1s2$nodename.tmp
fi	

### RECORD AFTER STATUS
# ---------------------
p1s1after=$(cat $TMPDIR/.p1s1$nodename.tmp | wc -l)
p1s2after=$(cat $TMPDIR/.p1s2$nodename.tmp | wc -l)

### SLACK ALERT for STATUS 1
# --------------------------
if [ $p1s1after -eq 5 ]
then
	$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "$DISCRIPTION" "#ffee00" "IPERF services not running $IP and $PORT"
fi

### SLACK ALERT for STATUS 2
# --------------------------
if [ $p1s2after -eq 5 ]
then
	$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "$DISCRIPTION" "#ffee00" "IPERF Server ($IP) Unavailable"
fi

### SLACK ALERT RECOVER for STATUS 1 
# ----------------------------------
if [ $p1s1before -ge 5 ]
then
	if [ $p1s1after -eq 0 ]
	then	
		$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "$DISCRIPTION" "#009b1f" "IPERF Server ($IP) Recovered"
	fi
fi

### SLACK ALERT RECOVER for STATUS 2 
# ----------------------------------
if [ $p1s2before -ge 5 ]
then
	if [ $p1s2after -eq 0 ]
	then	
		$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "$STATE" "$DISCRIPTION" "#009b1f" "IPERF Server ($IP) Recovered"
	fi
fi



##################################
#############	IPERF TEST PART 2
##################################


### LINESPEED divided by 5
# ------------------------
INCR=$(($LINESPEED / 5))
L1=$LINESPEED
L2=$(($L1 - $INCR))
L3=$(($L2 - $INCR))
L4=$(($L3 - $INCR))
L5=$(($L4 - $INCR))

### SET STATUS CODE
# -----------------
if [ $p1 -eq 0 ]
then
	if [ $SUM -lt $L5 ]				# status 5 = Extremely Low
	then
		echo 5 > $TMPDIR/.p2$nodename.tmp
	elif [ $SUM -lt $L4 ]				# status 4 = Very Low
	then
		echo 4 > $TMPDIR/.p2$nodename.tmp
	elif [ $SUM -lt $L3 ]				# status 3 = Low
	then
		echo 3 > $TMPDIR/.p2$nodename.tmp
	else
		echo 0 > $TMPDIR/.p2$nodename.tmp 	# status 0 = OK status
	fi
else	
	echo 1 > $TMPDIR/.p2$nodename.tmp 		# status 1 = Fail
fi

p2=$(cat $TMPDIR/.p2$nodename.tmp)

### ALERT NOTIFICATIONS PART1
# ----------------------------

### RECORD BEFORE STATUS
# ----------------------
p2s3before=$(cat $TMPDIR/.p2s3$nodename.tmp | wc -l)
p2s4before=$(cat $TMPDIR/.p2s4$nodename.tmp | wc -l)
p2s5before=$(cat $TMPDIR/.p2s5$nodename.tmp | wc -l)

### STATUS COUNTING
# -----------------
if [ $p2 -eq 5 ]
then 
	echo 5 >> $TMPDIR/.p2s5$nodename.tmp
elif [ $p2 -eq 4 ]
then
	echo 4 >> $TMPDIR/.p2s4$nodename.tmp
elif [ $p2 -eq 3 ]
then 
	echo 3 >> $TMPDIR/.p2s3$nodename.tmp
elif [ $p2 -eq 0 ]
then 
	### CLEAR STATUS
	# --------------
	rm -f $TMPDIR/.p2s5$nodename.tmp ; touch $TMPDIR/.p2s5$nodename.tmp
	rm -f $TMPDIR/.p2s4$nodename.tmp ; touch $TMPDIR/.p2s4$nodename.tmp
	rm -f $TMPDIR/.p2s3$nodename.tmp ; touch $TMPDIR/.p2s3$nodename.tmp
fi	

### RECORD AFTER STATUS
# ---------------------
p2s3after=$(cat $TMPDIR/.p2s3$nodename.tmp | wc -l)
p2s4after=$(cat $TMPDIR/.p2s4$nodename.tmp | wc -l)
p2s5after=$(cat $TMPDIR/.p2s5$nodename.tmp | wc -l)

### SLACK ALERT for STATUS 5 
# --------------------------
if [ $p2s5after -eq 5 ]
then
	$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "EXTREMELY LOW" "$DISCRIPTION" "#ff0000" "Line Speed $SUM"
fi

### SLACK ALERT for STATUS 4 
# --------------------------
if [ $p2s4after -eq 5 ]
then
	$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "VERY LOW" "$DISCRIPTION" "#ff0000" "Line Speed $SUM"
fi

### SLACK ALERT for STATUS 3 
# --------------------------
if [ $p2s3after -eq 5 ]
then
	$MAINDIR/data/data/slack.sh "$COMPANY" "$CHANNEL" "LOW" "$DISCRIPTION" "#ff0000" "Line Speed $SUM"
fi

### SLACK ALERT RECOVER for STATUS 5 
# ----------------------------------
if [ $p2s5before -ge 5 ]
then
	if [ $p2s5after -eq 0 ]
	then	
		$MAINDIR/data/data/slack.sh "$COMPANY" "$CHANNEL" "OK" "$DISCRIPTION" "#009b1f" "Line Speed $SUM"
	fi
fi

### SLACK ALERT RECOVER for STATUS 4 
# ----------------------------------
if [ $p2s4before -ge 5 ]
then
	if [ $p2s4after -eq 0 ]
	then	
		$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "OK" "$DISCRIPTION" "#009b1f" "Line Speed $SUM"
	fi
fi

### SLACK ALERT RECOVER for STATUS 3 
# ----------------------------------
if [ $p2s3before -ge 5 ]
then
	if [ $p2s3after -eq 0 ]
	then	
		$MAINDIR/data/slack.sh "$COMPANY" "$CHANNEL" "OK" "$DISCRIPTION" "#009b1f" "Line Speed $SUM"
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
echo "$DATE $TS - $TE, company=$COMPANY, discription=$DISCRIPTION,  speedtest(Mbps)=$SUM" >> $LOGFILE
