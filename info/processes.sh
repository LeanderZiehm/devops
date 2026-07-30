free -h

echo "===== TOP MEMORY ====="
ps aux --sort=-%mem | head -25

echo "===== TOP CPU ====="
ps aux --sort=-%cpu | head -25

echo "===== SERVICES ====="
systemctl list-units --type=service --state=running --no-pager

echo "===== ENABLED SERVICES ====="
systemctl list-unit-files --type=service --state=enabled --no-pager
