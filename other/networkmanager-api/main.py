import sys
import NetworkManager

def get_wifi_connections():
    """Retrieve all saved 802-11-wireless connections."""
    wifi_connections = []
    # Fetch saved connections from NetworkManager Settings
    for conn in NetworkManager.Settings.ListConnections():
        settings = conn.GetSettings()
        conn_type = settings.get("connection", {}).get("type")
        
        if conn_type == "802-11-wireless":
            name = settings["connection"]["id"]
            wifi_connections.append({
                "name": name,
                "uuid": settings["connection"]["uuid"],
                "object": conn
            })
    return wifi_connections

def get_wireless_device():
    """Find the first available wireless network interface."""
    for dev in NetworkManager.NetworkManager.GetDevices():
        if dev.DeviceType == NetworkManager.NM_DEVICE_TYPE_WIFI:
            return dev
    return None

def get_active_connection_uuids():
    """Get UUIDs of currently active connections."""
    active_uuids = []
    for active in NetworkManager.NetworkManager.ActiveConnections:
        # Some active connections might not have an associated Connection object
        if hasattr(active, "Connection") and active.Connection:
            settings = active.Connection.GetSettings()
            active_uuids.append(settings["connection"]["uuid"])
    return active_uuids

def main():
    dev = get_wireless_device()
    if not dev:
        print("Error: No Wi-Fi device found on this system.")
        sys.exit(1)

    print(f"Using Wi-Fi Interface: {dev.Interface}\n")
    
    wifi_list = get_wifi_connections()
    if not wifi_list:
        print("No saved Wi-Fi connections found.")
        sys.exit(0)

    active_uuids = get_active_connection_uuids()

    print("--- Configured Wi-Fi Connections ---")
    for idx, wifi in enumerate(wifi_list, 1):
        is_active = wifi["uuid"] in active_uuids
        status = " [ACTIVE]" if is_active else ""
        print(f"[{idx}] {wifi['name']}{status}")

    print("\nActions:")
    print(" - Enter a number to switch connections")
    print(" - Press Enter or 'q' to quit")
    
    choice = input("\nSelect an option: ").strip()
    
    if not choice or choice.lower() == 'q':
        print("Exiting.")
        sys.exit(0)

    if not choice.isdigit() or not (1 <= int(choice) <= len(wifi_list)):
        print("Invalid choice.")
        sys.exit(1)

    selected = wifi_list[int(choice) - 1]
    
    if selected["uuid"] in active_uuids:
        print(f"\nAlready connected to '{selected['name']}'.")
        return

    print(f"\nSwitching connection to '{selected['name']}'...")
    try:
        # ActivateConnection(Connection, Device, SpecificObject)
        # Pass "/" as SpecificObject when connecting via a saved connection profile
        NetworkManager.NetworkManager.ActivateConnection(selected["object"], dev, "/")
        print(f"Successfully triggered activation for {selected['name']}.")
    except Exception as e:
        print(f"Failed to switch connection: {e}")

if __name__ == "__main__":
    main()
