notify_me() {
  curl -X POST \
    "https://notify.leanderziehm.com/notify/me" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"$1\"}"
}

notify_me "User: $(whoami) | Device: $(getprop ro.product.vendor.marketname) | IPv4: $(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')" \
  >> ~/logs/notify.log 2>&1 & disown
