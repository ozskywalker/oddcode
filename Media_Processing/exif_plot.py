#!/usr/bin/env python3
#
# To get started:
#   pip3 install requests gmplot pillow
#   python3 exif_plot.py /path/to/dir
#   -or-
#   pip3 install requests gmplot pillow
#   python3 exif_plot.py /path/to/jpg
#
from collections import OrderedDict
from glob import glob
from sys import argv
from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS

import requests
import json
import webbrowser
import tempfile
import gmplot
import os
import glob
import datetime as dt

_default_zoom = 16
_geoservice = 'http://freegeoip.net/json'

def get_exif_data(image):
	"""Returns a dictionary from the exif data of an PIL Image item. Also converts the GPS Tags"""
	info = image._getexif()
	if not info:
		return {}
	exif_data = {TAGS.get(tag, tag): value for tag, value in info.items()}

	def is_fraction(val):
		return isinstance(val, tuple) and len(val) == 2 and isinstance(val[0], int) and isinstance(val[1], int)

	def frac_to_dec(frac):
		return float(frac[0]) / float(frac[1])

	if "GPSInfo" in exif_data:
		gpsinfo = {GPSTAGS.get(t, t): v for t, v in exif_data["GPSInfo"].items()}
		for tag, value in gpsinfo.items():
			if is_fraction(value):
				gpsinfo[tag] = frac_to_dec(value)
			elif all(is_fraction(x) for x in value):
				gpsinfo[tag] = tuple(map(frac_to_dec, value))
		exif_data["GPSInfo"] = gpsinfo
	return exif_data

def get_lat_lon(exif_data):
	"""Returns the latitude and longitude, if available, from the provided exif_data"""
	lat = None
	lon = None
	gps_info = exif_data.get("GPSInfo")

	def convert_to_degrees(value):
		d, m, s = value
		return d + (m / 60.0) + (s / 3600.0)

	if gps_info:
		gps_latitude = gps_info.get("GPSLatitude")
		gps_latitude_ref = gps_info.get("GPSLatitudeRef")
		gps_longitude = gps_info.get("GPSLongitude")
		gps_longitude_ref = gps_info.get("GPSLongitudeRef")

		if gps_latitude and gps_latitude_ref and gps_longitude and gps_longitude_ref:
			lat = convert_to_degrees(gps_latitude)
			if gps_latitude_ref != "N":
				lat = -lat

			lon = convert_to_degrees(gps_longitude)
			if gps_longitude_ref != "E":
				lon = -lon

	return lat, lon

def get_gps_datetime(exif_data):
	"""Returns the timestamp, if available, from the provided exif_data"""
	if "GPSInfo" not in exif_data:
		return None
	gps_info = exif_data["GPSInfo"]
	date_str = gps_info.get("GPSDateStamp")
	time = gps_info.get("GPSTimeStamp")
	if not date_str or not time:
		return None
	date = map(int, date_str.split(":"))
	timestamp = [*date, *map(int, time)]
	timestamp += [int((time[2] % 1) * 1e6)]  # microseconds
	return dt.datetime(*timestamp)

def clean_gps_info(exif_data):
	"""Return GPS EXIF info in a more convenient format from the provided exif_data"""
	gps_info = exif_data["GPSInfo"]
	cleaned = OrderedDict()
	cleaned["Latitude"], cleaned["Longitude"] = get_lat_lon(exif_data)
	cleaned["Altitude"] = gps_info.get("GPSAltitude")
	cleaned["Speed"] = gps_info.get("GPSSpeed")
	cleaned["SpeedRef"] = gps_info.get("GPSSpeedRef")
	cleaned["Track"] = gps_info.get("GPSTrack")
	cleaned["TrackRef"] = gps_info.get("GPSTrackRef")
	cleaned["TimeStamp"] = get_gps_datetime(exif_data)
	return cleaned

def get_geo_location():
	r = requests.get(_geoservice)
	j = json.loads(r.text)
	return j['latitude'], j['longitude']

if __name__ == "__main__":
	if len(argv) < 2:
		print("Usage:\n\t{} dir | image1".format(argv[0]))
		exit(255)
	
	imgs = []
	latitudes = []
	longitudes = []

	output = tempfile.gettempdir() + '/' + next(tempfile._get_candidate_names())
	(lat, lon) = get_geo_location()
	gmap = gmplot.GoogleMapPlotter(lat, lon, _default_zoom)

	if os.path.isfile(argv[1]):
		print("Processing single file %s" % (argv[1]))
		imgs.append(argv[1])

	elif os.path.isdir(argv[1]):
		print("Processing directory %s" % (argv[1]))
		fcnt = 0
		fskip = 0

		for d, s, f in os.walk(argv[1]):
			for fname in f:
				if '.jpg' in fname:
					imgs.append(os.path.realpath(d + '/' + fname))
					fcnt += 1
				else:
					fskip += 1

		print("Found %d files, skipped %d" % (fcnt, fskip))

	else:
		print("ERR: I don't know what %s is" % (argv[1]))
		sys.exit(255)

	ffail = 0
	for img in imgs:
		with Image.open(img) as image:
			try:
				exif_data = get_exif_data(image)
				gps_info = clean_gps_info(exif_data)
				gmap.marker(gps_info["Latitude"], gps_info["Longitude"])
			except:
				ffail += 1
				pass
			#latitudes.append(gps_info["Latitude"])
			#longitudes.append(gps_info["Longitude"])

	print("Extracted EXIF info from %d files, found %d with missing GPS Info" % (len(imgs), ffail))

	#gmap.plot(latitudes, longitudes, 'cornflowerblue', edge_width=10)
	print("Generating HTML")
	gmap.draw(output)

	print("Calling default browser with %s" % (output))
	webbrowser.open('file://' + os.path.realpath(output))
