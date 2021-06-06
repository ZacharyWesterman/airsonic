#!/usr/bin/python3
# Call out to AudD to attempt to get audio information (filename is in argv[1])

# Note that AudD requires an API token.
# This should be stored in "audd_api_token.txt",
# which should NEVER be committed!

import requests, json, sys

with open('audd_api_token.txt', 'r') as file:
	api_token = file.readline().rstrip()

data = {
	'Content-Type': 'multipart/form-data',
	'return': 'musicbrainz,spotify',
	'api_token': api_token
}

myFiles={'file': open(sys.argv[1],'rb')}
result = requests.post('https://api.audd.io/', data=data, files=myFiles)
data = json.loads(result.text)

if ('status' in data) and (data['status'] == 'success') and ('result' in data):
	result = data['result']
	if result is not None:
		if 'album' in result:
			print('Album: ' + result['album'])
		if 'title' in result:
			print('Title: ' + result['title'])
		if 'artist' in result:
			print('Artist: ' + result['artist'])
		if 'genre' in result:
			print('Genre: ' + result['genre'])
