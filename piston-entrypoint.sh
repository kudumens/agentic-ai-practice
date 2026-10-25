#!/bin/bash
set -e

cd /sys/fs/cgroup
mkdir -p isolate
echo 1 > isolate/cgroup.procs
echo '+cpuset +cpu +io +memory +pids' > cgroup.subtree_control
cd isolate
mkdir -p init
echo 1 > init/cgroup.procs
echo '+cpuset +memory' > cgroup.subtree_control

echo "Initialized cgroup"
mkdir -p /piston
chown -R piston:piston /piston /piston_api
exec su -- piston -c 'ulimit -n 65536 && node /piston_api/src'
