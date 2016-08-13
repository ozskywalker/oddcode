#!/usr/bin/env python
import sys, json, urllib, urllib2

droplet_name = 'dropletnamehere'
token = 'digitaloceantokenhere'

try:
	print 'helloooooo mothership'

	req = urllib2.Request('https://api.digitalocean.com/v2/droplets?page=1&per_page=1')
	req.add_header('Content-Type', 'application/json')
	req.add_header('Authorization', 'Bearer ' + token)

	data = json.load(urllib2.urlopen(req))
except:
	print 'guess the mothership don\'t like us'
	print sys.exc_info()[0]
	raise

if len(data['droplets']) > 0:
	for droplet in data['droplets']:
		if droplet['name'].find(droplet_name + '%'):
			print 'found %s [id=%s, slug=%s (%s)]' % (droplet_name, droplet['id'], droplet['region']['slug'], droplet['region']['name'])
			print 'droplet is', droplet['status'].upper()
			if droplet['status'].upper() == 'OFF':
				ask = raw_input('power ON? ')
				if ask == 'y' or ask == 'yes':
					data = urllib.urlencode({'type':'power_on'})
					url = 'https://api.digitalocean.com/v2/droplets/%s/actions' % (droplet['id'])
					req = urllib2.Request(url, data)
					req.add_header('Authorization', 'Bearer ' + token)
					res = json.load(urllib2.urlopen(req))

					print 'launched, tracking as action', res['action']['id']
					print 'wait 20-30 seconds'

					# add monitoring using this call -> https://developers.digitalocean.com/documentation/v2/#retrieve-an-existing-action

			if droplet['status'].upper() == 'ACTIVE':
				ask = raw_input('power OFF?? ')
				if ask == 'y' or ask == 'yes':
					data = urllib.urlencode({'type':'shutdown'})
					url = 'https://api.digitalocean.com/v2/droplets/%s/actions' % (droplet['id'])
					req = urllib2.Request(url, data)
					req.add_header('Authorization', 'Bearer ' + token)
					res = json.load(urllib2.urlopen(req))

					print 'launched, tracking as action', res['action']['id']

			print 'use', droplet['networks']['v4'][0]['ip_address']
else:
	print 'no droplet found? FREAK OUT'
	exit
