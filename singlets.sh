#!/usr/bin/bash

cd /home/airsonic/Music || exit 1

dest='/home/airsonic/Music/Various Artists/Miscellaneous'
mkdir -p "$dest"

for artist in *
do
	doskip=0
	for album in "$artist"/*
	do
		songs=( "$album"/* )
		ct=${#songs[@]}
		[ "$ct" -gt 1 ] && doskip=1 && break
	done
	[ $doskip == 1 ] && continue

	#at this point, only artists with albums that contain a single song each
	echo "$artist:"
	while read song
	do
		echo "    $song"
		mv "$song" "$dest/"
	done < <(find "$artist" -type f)
	rm -rf "$artist"
done
