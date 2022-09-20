#!/usr/bin/env bash

declare -A tags=()

#first param must be a file
if [ ! -z "$filename" ] && [ -e "$filename" ]
then
	while read __temp
	do
		tags["${__temp%%: *}"]="${__temp#*: }"
	done < <(exiftool -s -s -Artist -AlbumArtist -Album -AlbumTitle -MediaType -Genre -Title "$filename")

	#perform tag conversions to make "MediaType" actually reflect the type of media we have
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
	[ "${tags[MediaType]}" == "Children's" ] && tags[MediaType]=Audiobook

	#strip slashes out of Artist & Album so we can organize as directories
	tags[Artist]="$(sed -e 's/[\///]//g' <<< "${tags[Artist]}")"
	tags[Album]="$(sed -e 's/[\///]//g' <<< "${tags[Album]}")"
fi
