# Hotspot Fix for RPi with WiFi + Ethernet

## Overview

Your Raspberry Pi has both **WiFi** and **Ethernet** connections for internet access. The hotspot fix script has been updated to:

- ✅ Configure WiFi hotspot (wlan0) for provisioning portal
- ✅ Preserve Ethernet connection (eth0) for internet access
- ✅ Work with both connections active simultaneously

## Quick Start

### Step 1: Find RPi IP Address

Since RPi has both WiFi and Ethernet, it might be on a different IP:

```bash
# Option 1: Use the find script
./find-rpi-ip.sh

# Option 2: Check your router's connected devices list
# Look for "ShawnRaspberryPi" or MAC address

# Option 3: Try known IPs
ping 192.168.0.214
ping 192.168.4.1
```

### Step 2: Deploy Fix

```bash
# If you know the IP:
RPI_IP=192.168.0.214 ./deploy-hotspot-fix.sh

# Or let it auto-detect:
./deploy-hotspot-fix.sh
```

## How It Works

### Network Configuration

```
┌─────────────────────────────────────┐
│     Raspberry Pi                    │
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │  Ethernet   │  │    WiFi      │ │
│  │   (eth0)    │  │   (wlan0)    │ │
│  │             │  │              │ │
│  │ Internet    │  │  Hotspot     │ │
│  │ Access      │  │  192.168.4.1 │ │
│  │             │  │              │ │
│  └─────────────┘  └──────────────┘ │
│       ✅              ✅              │
│    Preserved      Configured       │
└─────────────────────────────────────┘
```

### What the Fix Does

1. **Checks NetworkManager** - Ensures it's running
2. **Preserves Ethernet** - Keeps eth0 connection intact
3. **Configures WiFi Hotspot** - Sets up wlan0 as hotspot
4. **Forces IP Address** - Sets wlan0 to 192.168.4.1
5. **Restarts Portal** - Ensures provisioning portal is running

### Key Points

- **Ethernet (eth0)**: Remains connected for internet access
- **WiFi (wlan0)**: Configured as hotspot for provisioning
- **Both active**: RPi can have internet via Ethernet while providing hotspot

## Deployment Methods

### Method 1: Auto-Detection (Recommended)

```bash
./deploy-hotspot-fix.sh
```

The script will:
- Try known IPs (192.168.0.214, 192.168.4.1)
- Check ARP table for RPi
- Auto-detect the correct IP

### Method 2: Manual IP

```bash
# If you know the RPi IP (from router or find script)
RPI_IP=192.168.0.215 ./deploy-hotspot-fix.sh
```

### Method 3: Via Hotspot

If RPi is in hotspot mode:

1. Connect Mac to hotspot WiFi: `AIOD-Camera-XXXXX`
2. Run: `./deploy-hotspot-fix-via-hotspot.sh`

### Method 4: Find IP First

```bash
# Find RPi IP
./find-rpi-ip.sh

# Then deploy with found IP
RPI_IP=<found_ip> ./deploy-hotspot-fix.sh
```

## Verification

After running the fix, verify both connections:

```bash
# On RPi, check:
ip addr show eth0    # Should show Ethernet IP (e.g., 192.168.0.214)
ip addr show wlan0  # Should show 192.168.4.1

# Check active connections
nmcli connection show --active

# Test internet (via Ethernet)
ping -c 2 8.8.8.8

# Test hotspot (via WiFi)
curl http://192.168.4.1
```

## Troubleshooting

### RPi Not Reachable

Since RPi has both connections, it might be on a different IP:

1. **Check router admin panel:**
   - Look for "ShawnRaspberryPi" in connected devices
   - Note the IP address

2. **Use find script:**
   ```bash
   ./find-rpi-ip.sh
   ```

3. **Check ARP table:**
   ```bash
   arp -a | grep -i raspberry
   ```

4. **Try common IPs:**
   ```bash
   for ip in 192.168.0.{200..220}; do
       ping -c 1 -W 1 $ip > /dev/null 2>&1 && echo "$ip is reachable"
   done
   ```

### Hotspot Not Working

Even with Ethernet connected, hotspot should work:

1. **Check WiFi interface:**
   ```bash
   ip addr show wlan0
   ```

2. **Verify hotspot is active:**
   ```bash
   nmcli connection show --active | grep Hotspot
   ```

3. **Check portal service:**
   ```bash
   sudo systemctl status provisioning-portal
   ```

### Internet Not Working

If internet stops working after fix:

1. **Check Ethernet connection:**
   ```bash
   ip addr show eth0
   nmcli connection show --active | grep eth0
   ```

2. **Restart Ethernet:**
   ```bash
   sudo nmcli connection down <eth0-connection-name>
   sudo nmcli connection up <eth0-connection-name>
   ```

## Files

- `deploy-hotspot-fix.sh` - Main deployment (auto-detects IP)
- `find-rpi-ip.sh` - Find RPi IP on network
- `camera-system/fix-hotspot.sh` - The actual fix script
- `deploy-hotspot-fix-via-hotspot.sh` - Deploy via hotspot connection

## Summary

✅ **Ethernet preserved** - Internet access maintained  
✅ **WiFi hotspot configured** - Provisioning portal accessible  
✅ **Both connections active** - Best of both worlds  
✅ **Auto-detection** - Scripts find RPi automatically  

The fix ensures your RPi can:
- Provide internet access via Ethernet
- Host provisioning portal via WiFi hotspot
- Work with both connections simultaneously

