#!/bin/bash
for file in Music Audiobooks Soundtracks; do while read i; do f="$(pwd)/$i"; echo "$f"; done < <(find "$file" -type f) >"$file".m3u; done

