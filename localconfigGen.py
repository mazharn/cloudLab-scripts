#!/usr/bin/python
# This file generates the CloudLab cluster configuration, which will be
# automatically included by config.py.

import subprocess
from sys import argv

num_rcXX = int(argv[1])
hosts = []
for i in range(1, num_rcXX + 1):
    result = subprocess.Popen(['rsh', 'rc%02d' % i, 'hostname -A; hostname -i'],
        stdout=subprocess.PIPE).communicate()[0]
    hostname = result.split('.', 1)[0]
    ipAddr = result.splitlines()[1]
    hosts.append((hostname, ipAddr, i))

print 'hosts = %s' % hosts
print '''
default_disk1 = '-f /dev/sdb'

default_disk2 = '-f /dev/sdb,/dev/sdc'
'''
