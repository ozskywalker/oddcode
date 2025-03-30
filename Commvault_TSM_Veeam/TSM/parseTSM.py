#!/usr/bin/python3
# Quick and dirty script to scrape backup completion times from a TSM mmbackup log

import sys
import re
from datetime import datetime

# assumes locale is en_US
TSM_date_format = "%a %b %d %X  %Y"

def days_between(d1, d2):
    d1 = datetime.strptime(d1, TSM_date_format)
    d2 = datetime.strptime(d2, TSM_date_format)
    return abs((d2 - d1).days)

if __name__ == '__main__':
    TSM_log_regex = re.compile(r"^mmbackup: Backup of (.*) (begins|completed).*(\w{3}\s\w{3}\s\d{1,2}\s\d\d:\d\d:\d\d\s)[a-zA-Z]*.(\d{4})\.$")
    with open(sys.argv[1], "r") as in_file:
        for line in in_file:
            m = TSM_log_regex.search(line)
            if m:
                if m.group(2) == "begins":
                    path = m.group(1)
                    status = m.group(2)
                    time = m.group(3) + ' ' + m.group(4)
                elif m.group(2) == "completed":
                    end_time = m.group(3) + ' ' + m.group(4)
                    delta = datetime.strptime(end_time, TSM_date_format) - datetime.strptime(time, TSM_date_format)
                    print("Path %s took %s to complete" % (path, delta))
