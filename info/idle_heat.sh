# sudo dnf install sysstat lm_sensors powertop procps-ng upower
# sudo systemctl enable --now lm_sensors
# sudo sensors-detect
# sudo powertop
# systemd-cgtop

#!/bin/bash

echo "=============================="
echo " Fedora System KPI Snapshot"
echo " $(date)"
echo "=============================="

echo
echo "CPU:"
uptime
echo

echo "CPU Usage:"
top -bn1 | grep "Cpu(s)"

echo
echo "Processes:"
echo "Total:"
ps aux | wc -l

echo "Running:"
ps -eo state | grep -c R

echo
echo "Top CPU Consumers:"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -10

echo
echo "Memory:"
free -h

echo
echo "Temperature:"
sensors 2>/dev/null | grep -i "temp"

echo
echo "Disk Activity:"
iostat -xz 1 1 | tail -20

echo
echo "Network Connections:"
ss -tun | wc -l

echo
echo "Power Estimate:"
sudo powertop --time=5 --html=/tmp/powertop.html >/dev/null 2>&1
grep -i "power" /tmp/powertop.html | head

echo
echo "Background Services:"
systemctl list-units --type=service --state=running | wc -l

echo
echo "Top Wakeup Sources (requires root):"
sudo powertop --csv=/tmp/powertop.csv --time=5 >/dev/null 2>&1
head -20 /tmp/powertop.csv

echo
echo "=============================="
echo "Done"