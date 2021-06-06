#!/usr/bin/bash

#check dependencies and exit if any are not met
src/require.sh || exit 1

#make sure we're in this script's working dir
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

begin=$(date +%s)

temp1=/var/tmp/Incoming
temp2=/var/tmp/Incoming2
convtemp=/tmp/conversion

rm -rf $temp1
[ -d /home/airsonic/Music/Incoming ] || exit 0
mv /home/airsonic/Music/Incoming $temp1

cd $temp1 || exit 1
rm -rf $temp2 $convtemp
mkdir $temp2

# Do an initial scan of the folder, get metadata about the files and organize them
while read filename
do
	#ignore any files that are not just audio
	[ "$(file "$filename" | grep -iE '(audio|stereo)')" == '' ] && continue
	echo "$filename"
	outfilename="$(basename "$filename")"

	#Get all the tags
	. src/tags.sh

	# If we don't know the artist or the album, call out to audD.
	# Note that this may fail.. only 300 calls per month are free.
	if [ "${tags[Artist]}" == '' ] || [ "${tags[Album]}" == '' ]
	then
		rm -rf "$convtemp"
		mkdir "$convtemp"
		ffmpeg -i "$filename" "$convtemp/full.wav" -loglevel warning -y </dev/null #convert to wav
		sox "$convtemp/full.wav" "$convtemp/short.wav" trim 0 10 #get first 10 seconds
		if [ -e "$convtemp/short.wav" ]
		then
			#read tags from audd call.
			while read k
			do
				tags["${k%%: *}"]="${k#*: }"
			done < <(src/audd.py "$convtemp/short.wav")
			. src/tags.sh

			#Write the appropriate metadata
			ext="${filename##*.}"
			tofile="$convtemp/full.$ext"
			ffmpeg -i "$filename" -c copy -metadata artist="${tags[Artist]}" -metadata album="${tags[Album]}" -metadata title="${tags[Title]}" "$tofile" -loglevel warning -y </dev/null
			if [ -e "$tofile" ]
			then
				[ "${tags[Title]}" != '' ] && outfilename="$(sed -e 's/[\///]//g' <<< "${tags[Title]}.$ext")"
				filename="$tofile"
			fi

			echo "Imported info for \"${tags[Title]}\""
		fi
	fi

	folder="$temp2/album.temp--${tags[Album]}"
	mkdir -p "$folder"

	mv "$filename" "$folder/$outfilename"
	echo "${tags[Artist]}" >> "$folder/artists.txt"
	echo "${tags[MediaType]}" >> "$folder/types.txt"
done < <(find . -type f)

#Evaluate where each of the organized albums should go.
cd $temp2 || exit 2
for folder in *
do
	Album="${folder#album.temp--*}"
	[ "$Album" == '' ] && Album='Unknown Album'

	. src/frequent.sh "$folder/types.txt" 80
	MediaType="$mostFreq"

	. src/frequent.sh "$folder/artists.txt" 75
	[ "$mostFreq" == '' ] && mostFreq='Unknown Artist'
	[ "$mostFreqCt" -lt "$goal" ] && mostFreq='Various Artists'
	Artist="$mostFreq"

	rm "$folder/types.txt" "$folder/artists.txt"

	prefix=/home/airsonic/Music
	[ "$MediaType" == 'Audiobook' ] && prefix=/home/airsonic/Audiobooks
	[ "$MediaType" == 'Soundtrack' ] && prefix=/home/airsonic/Soundtracks

	dest="$prefix/$Artist/$Album"
	mkdir -p "$dest"

	for srcfile in "$folder"/*
	do
		destfile="$dest/$(basename "$srcfile")"
		#[ -e "$destfile" ] && echo "$destfile Already exists! Skipping."
		#[ ! -e "$destfile" ] && mv "$srcfile" "$destfile"
		mv "$srcfile" "$destfile"
	done
done

rm -rf $temp2

finish=$(date +%s)
echo "$(date) import completed in $((finish - begin)) seconds."
