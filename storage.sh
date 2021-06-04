#!/bin/bash

result=($(df /home/airsonic | tail -n 1 | tr -d '%'))

total=${result[1]}
used=${result[2]}
free=${result[3]}
percent=${result[4]}

threshold=30

if [ "$percent" -gt "$threshold" ]
then
	curl https://textbelt.com/text -d key=textbelt -d number=8322054018 -d message="Airsonic: Disk usage is ${used}/${total}(${percent}%), past the ${threshold}% threshold! ${free} remaining."
fi
