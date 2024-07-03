#!/bin/bash

if [ "$#" -lt 1 ]
then
	>&2 echo "ERROR: No directories specified. Please specify at least one directory to convert."
	exit 1
fi

for folder in "$@"
do
	if [ ! -d "$folder" ]
	then
		>&2 echo "ERROR: \"$folder\" is not a directory!"
		exit 1
	fi
done

cwd=$(pwd)

#make sure we're in this script's working dir
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

#check dependencies and exit if any are not met
src/require.sh || exit 1

cd "$cwd" || exit 1

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
for folder in "$@"
do
	ct="$(find "$folder/" -type f \( -name '*.m4a' -or -name '*.m4b' \) | wc -l)"
	TOTAL=$((TOTAL + ct))
done
echo " $TOTAL files will be converted."

CURRENT=0
PIDS=()
for folder in "$@"
do
	while read src
	do
		[ ! -e "$src" ] && continue

		CURRENT=$((CURRENT + 1))

		while [ "${#PIDS[@]}" -gt "$MAXPROC" ]
		do
			#Remove any pids that are finished
			pids=("${PIDS[@]}")
			PIDS=()
			for pid in "${pids[@]}"
			do
				if [[ ! -e /proc/"$pid" ]]
				then
					wait "$pid"
				else
					PIDS+=("$pid")
				fi
			done

			sleep 1
		done

		convert_file "$src" "$CURRENT" "$TOTAL" &
		PIDS+=($!)
		sleep .1
	done < <(find "$folder/" -type f \( -name '*.m4a' -or -name '*.m4b' \))
done

wait

echo "All $TOTAL files have been converted."
