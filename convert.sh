#!/bin/bash

#make sure we're in this script's working dir
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

#check dependencies and exit if any are not met
src/require.sh || exit 1

cd /home/airsonic || exit 1

#Convert a given file to mp3
convert_file()
{
	local src
	local mp3
	local total
	local current

	src="$1"
	mp3="${src%.*}.mp3"

	current="$2"
	total="$3"

	echo "[$current/$total] Converting: $(basename "$mp3")"

	ffmpeg -i "$src" "$mp3" -y -loglevel error -nostats </dev/null >/dev/null && rm "$src"
}

MAXPROC=$(nproc)
MAXPROC=$((MAXPROC - 1))

echo -n 'Counting files...'
TOTAL=0
for folder in Audiobooks Music Soundtracks
do
	ct="$(find "$folder/" -type f \( -name '*.m4a' -or -name '*.m4b' \) | wc -l)"
	TOTAL=$((TOTAL + ct))
done
echo " $TOTAL files will be converted."

CURRENT=0
for folder in Audiobooks Music Soundtracks
do
	ct=0
	while read src
	do
		CURRENT=$((CURRENT + 1))
		ct=$((ct+1))
		[ "$ct" -gt "$MAXPROC" ] && ct=0 && wait
		convert_file "$src" "$CURRENT" "$TOTAL" &
	done < <(find "$folder/" -type f \( -name '*.m4a' -or -name '*.m4b' \))
	wait
done

echo "All $TOTAL files have been converted."
