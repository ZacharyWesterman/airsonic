#!/usr/bin/bash

#make sure we're in this script's working dir
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
srcdir="$(pwd)/src"

#check dependencies and exit if any are not met
"$srcdir/require.sh" || exit 1

begin=$(date +%s)

temp1=/mnt/storage/tmp/Incoming
temp2=/mnt/storage/tmp/Incoming2
convtemp=/mnt/storage/tmp/conversion

rm -rf $temp1
[ -d /mnt/storage/data/airsonic/Music/Incoming ] || exit 0

echo "$(date) import started"

mv /mnt/storage/data/airsonic/Music/Incoming $temp1

cd $temp1 || exit 1
rm -rf $temp2 $convtemp
mkdir $temp2

# Unzip any archive uploads
for filename in *.zip
do
	# Just overwrite (-o) any existing files, don't prompt.
	unzip -o "$filename" && rm "$filename"
done

echo '---- Analyzing Input ----'

# Do an initial scan of the folder, get metadata about the files and organize them
while read -r filename
do
	#ignore any files that are not just audio
	[ "$(file "$filename" | grep -iE '(audio|stereo)')" == '' ] && continue
	echo "$filename"
	outfilename="$(basename "$filename")"

	#Get all the tags
	. "$srcdir/tags.sh"

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
			if [ -e audd_api_token.txt ]; then
				while read -r k
				do
					tags["${k%%: *}"]="${k#*: }"
				done < <("$srcdir/audd.py" "$convtemp/short.wav")
			fi
			. "$srcdir/tags.sh"

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

echo '---- Sending to Output ----'

#Evaluate where each of the organized albums should go.
cd $temp2 || exit 2
for folder in *
do
	Album="${folder#album.temp--*}"
	[ "$Album" == '' ] && Album='Unknown Album'

	. "$srcdir/frequent.sh" "$folder/types.txt" 80
	MediaType="$mostFreq"

	. "$srcdir/frequent.sh" "$folder/artists.txt" 75
	[ "$mostFreq" == '' ] && mostFreq='Unknown Artist'
	[ "$mostFreqCt" -lt "$goal" ] && mostFreq='Various Artists'
	Artist="$mostFreq"

	rm "$folder/types.txt" "$folder/artists.txt"

	prefix=/mnt/storage/data/airsonic/Music
	[ "$MediaType" == 'Audiobook' ] && prefix=/mnt/storage/data/airsonic/Audiobooks
	[ "$MediaType" == 'Soundtrack' ] && prefix=/mnt/storage/data/airsonic/Soundtracks

	dest="$prefix/$Artist/$Album"
	mkdir -p "$dest"

	for srcfile in "$folder"/*
	do
		destfile="$dest/$(basename "$srcfile")"
		#[ -e "$destfile" ] && echo "$destfile Already exists! Skipping."
		#[ ! -e "$destfile" ] && mv "$srcfile" "$destfile"
		mv "$srcfile" "$destfile"
		echo "$destfile"
	done
done

rm -rf $temp2

finish=$(date +%s)
echo "$(date) import completed in $((finish - begin)) seconds."
echo
