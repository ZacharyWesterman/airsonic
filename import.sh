#!/usr/bin/bash

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

declare -A tags

function setTags()
{
	[ "${tags[Artist]}" == '' ] && tags[Artist]="${tags[AlbumArtist]}"
	[[ "${tags[Artist]^^}" == *'UNKNOWN'* ]] && tags[Artist]=''
	[ "${tags[Album]}" == '' ] && tags[Album]="${tags[AlbumTitle]}"
	[[ "${tags[Album]^^}" == *'UNKNOWN'* ]] && tags[Album]=''
	[ "${tags[MediaType]}" == '' ] && tags[MediaType]="${tags[Genre]}"
	[ "${tags[MediaType]}" == 'Spoken & Audio' ] && tags[MediaType]=Audiobook
	[ "${tags[MediaType]}" == 'Audio Drama' ] && tags[MediaType]=Audiobook
	[ "${tags[MediaType]}" == 'Spoken Word' ] && tags[MediaType]=Audiobook
	[ "${tags[MediaType]}" == 'Podcast' ] && tags[MediaType]=Audiobook
	[ "${tags[MediaType]}" == 'Film' ] && tags[MediaType]=Soundtrack
	[ "${tags[Artist]}" == 'Soundtrack' ] && tags[MediaType]=Soundtrack
	[ "${tags[MediaType]}" == 'None' ] && tags[MediaType]=Audiobook
	tags[Artist]="$(sed -e 's/[\///]//g' <<< "${tags[Artist]}")"
	tags[Album]="$(sed -e 's/[\///]//g' <<< "${tags[Album]}")"
}

# Do an initial scan of the folder, get metadata about the files and organize them
while read filename
do
	#ignore any files that are not just audio
	[ "$(file "$filename" | grep -iE '(audio|stereo)')" == '' ] && continue
	echo "$filename"
	outfilename="$(basename "$filename")"

	tags=()
	while read k
	do
		tags["${k%%: *}"]="${k#*: }"
	done < <(exiftool -s -s -Artist -AlbumArtist -Album -AlbumTitle -MediaType -Genre -Title "$filename")
	setTags

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
			done < <(/home/airsonic/scripts/audd.py "$convtemp/short.wav")
			setTags

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

#Input should be the list filename and a percent goal
function getMostFrequent()
{
	mostFreq=''
	mostFreqCt=0
	totalCt=0

	while read count value
	do
		[ "$mostFreq" == '' ] && mostFreq="$value" && mostFreqCt="$count"
		totalCt=$((totalCt + count))
	done < <(sort "$1" | uniq -c | sort -n -r)
	goal=$((totalCt * "$2" / 100))
}

#Evaluate where each of the organized albums should go.
cd $temp2 || exit 2
for folder in *
do
	Album="${folder#album.temp--*}"
	[ "$Album" == '' ] && Album='Unknown Album'

	getMostFrequent "$folder/types.txt" 80
	MediaType="$mostFreq"

	getMostFrequent "$folder/artists.txt" 75
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
