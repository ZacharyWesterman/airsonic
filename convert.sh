#!/bin/bash

#make sure we're in this script's working dir
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

#check dependencies and exit if any are not met
src/require.sh || exit 1

cd /home/airsonic || exit 1

while read m4a
do
	mp3="${m4a%.m4a*}.mp3"
	</dev/null ffmpeg -i "$m4a" "$mp3" -y -loglevel error -nostats && rm "$m4a"
	echo "$mp3"
done < <(find . -type f -name '*.m4a')

while read m4b
do
	mp3="${m4b%.m4b*}.mp3"
	</dev/null ffmpeg -i "$m4b" "$mp3" -y -loglevel error -nostats && rm "$m4b"
	echo "$mp3"
done < <(find . -type f -name '*.m4b')
