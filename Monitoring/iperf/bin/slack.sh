#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# ALIASES
username=$1
channel=$2
title=$3
pretext=$4
color=$5
line1=$6
line2=$7
line3=$8
line4=$9

# SLACK WEBHOOK URL
SLACKURL="https://hooks.slack.com/services/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"

# Escaping text in lines
l1=$(echo $line1 | sed 's/"/\"/g' | sed "s/'/\'/g" )
l2=$(echo $line2 | sed 's/"/\"/g' | sed "s/'/\'/g" )
l3=$(echo $line3 | sed 's/"/\"/g' | sed "s/'/\'/g" )
l4=$(echo $line4 | sed 's/"/\"/g' | sed "s/'/\'/g" )

# MESSAGE FORMAT
json="{
	\"channel\": \"#$channel\",
	\"username\": \"$username\",
	\"attachments\":[{
		\"title\": \"$title\",
		\"pretext\": \"$pretext\",
		\"color\": \"$color\",
		\"text\": \"$l1\n$l2\n$l3\n$l4\"
	}]
}"

# Send everything with curl
curl -s -d "payload=$json" "$SLACKURL" -o /dev/null
