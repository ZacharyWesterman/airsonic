#!/usr/bin/env bash

#get most common value from a list
#Input should be the list filename and a percent goal

mostFreq=''
mostFreqCt=0
totalCt=0

while read count value
do
	[ "$mostFreq" == '' ] && mostFreq="$value" && mostFreqCt="$count"
	totalCt=$((totalCt + count))
done < <(sort "$1" | uniq -c | sort -n -r)
goal=$((totalCt * "$2" / 100))
