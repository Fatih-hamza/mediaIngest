# Quick Installation Guide

Deploy the entire Media Ingest System with a single command on your Proxmox host!

## Prerequisites

- ✅ Proxmox VE 7.x or 8.x
- ✅ Root access to Proxmox host
- ✅ Internet connection
- ✅ NAS or network storage already mounted on Proxmox
- ✅ At least 8GB free disk space for LXC container

---

## Automated Installation (Recommended)

### Step 1: Run on Proxmox Host

```bash
bash -c "$(wget -qLO - http://192.168.1.14:3000/spooky/mediaingestDashboard/raw/branch/main/install.sh)"
```

Or download first to review:

```bash
wget http://192.168.1.14:3000/spooky/mediaingestDashboard/raw/branch/main/install.sh
bash install.sh
```

### Step 2: Follow Interactive Prompts

The installer will ask you for:

**Container Configuration:**
- Container ID (default: `105`)
- Container name (default: `media-ingest`)
- Root password for the container
- CPU cores (default: `2`)
- Memory in MB (default: `2048`)
- Disk size in GB (default: `8`)

**Storage Configuration:**
- NAS mount path on Proxmox host (e.g., `/mnt/pve/media-nas`)
  - This is where your media files will be synced to
  - The path must already exist and be mounted

**Network Configuration:**
- IP address: Enter static IP in CIDR format (e.g., `192.168.1.100/24`) or press Enter for DHCP
- Gateway: Required if using static IP
- DNS server: Default is `8.8.8.8`

### Step 3: Installation Progress

Watch as the installer:

```
[Phase 1] Proxmox Host Configuration
  ✓ Creating USB trigger script
  ✓ Mount point /mnt/usb-pass created
  ✓ udev rules configured

[Phase 2] LXC Container Creation
  ✓ Container 105 created
  ✓ Bind mounts configured
  ✓ Container started

[Phase 3] Container Bootstrap
  ✓ Package lists updated
  ✓ Base dependencies installed
  ✓ Node.js installed
  ✓ Ingest script deployed

[Phase 4] Dashboard Deployment
  ✓ Repository cloned
  ✓ Backend dependencies installed
  ✓ Frontend built
  ✓ Dashboard service started
```

### Step 4: Access Dashboard

After installation completes, you'll see:

```
════════════════════════════════════════════════════════════════
               Installation Complete! 🎉
════════════════════════════════════════════════════════════════

Container Information:
  ID: 105
  Name: media-ingest
  IP: 192.168.1.100

Dashboard Access:
  http://192.168.1.100:3000

Mount Points:
  USB: /media/usb-ingest
  NAS: /media/nas
```

Open the dashboard URL in your browser!

---

## What Gets Installed

### On Proxmox Host:
- `/usr/local/bin/usb-trigger.sh` - USB detection and mounting script
- `/etc/udev/rules.d/99-ingest.rules` - Automatic USB detection rules
- `/mnt/usb-pass` - Mount point for USB drives
- `/var/log/usb-trigger.log` - USB trigger event log

### Inside LXC Container:
- `/opt/dashboard/` - Dashboard application (React + Node.js)
- `/usr/local/bin/ingest-media.sh` - Rsync automation script
- `/var/log/media-ingest.log` - Transfer progress log
- `/etc/systemd/system/ingest-dashboard.service` - Dashboard systemd service
- Node.js 18.x, rsync, ntfs-3g, and dependencies

---

## Post-Installation

### Test USB Detection

1. Plug in a USB drive with a folder structure like:
   ```
   USB Drive
   └── Media/
       ├── Movies/
       ├── Series/
       └── Anime/
   ```

2. The system will:
   - Detect USB insertion automatically
   - Mount the drive
   - Start syncing to NAS
   - Show live progress on dashboard

### View Logs

```bash
# USB trigger logs (on Proxmox host)
tail -f /var/log/usb-trigger.log

# Transfer progress logs (inside container)
pct exec 105 -- tail -f /var/log/media-ingest.log

# Dashboard service logs
pct exec 105 -- journalctl -u ingest-dashboard.service -f
```

### Useful Commands

```bash
# Access container shell
pct enter 105

# Restart dashboard service
pct exec 105 -- systemctl restart ingest-dashboard.service

# Check service status
pct exec 105 -- systemctl status ingest-dashboard.service

# Stop/start container
pct stop 105
pct start 105

# Test USB trigger manually
bash /usr/local/bin/usb-trigger.sh /dev/sdb
```

---

## Customization

### Add Custom Sync Folders

Edit the ingest script inside the container:

```bash
pct exec 105 -- nano /usr/local/bin/ingest-media.sh
```

Add lines like:
```bash
sync_folder "Documentaries"
sync_folder "Music"
sync_folder "Photos"
```

### Change NAS Path

Edit container bind mount:
```bash
pct set 105 -mp1 /new/nas/path,mp=/media/nas
pct reboot 105
```

### Configure Firewall

If using Proxmox firewall, allow port 3000:
```bash
# In Datacenter → Firewall → Add
# Direction: In
# Action: ACCEPT
# Protocol: TCP
# Dest. port: 3000
# Comment: Media Ingest Dashboard
```

---

## Troubleshooting

### Installation Failed

Check the error message and try:

```bash
# Update Proxmox repositories
apt update

# Download Debian template manually
pveam update
pveam available | grep debian-12
pveam download local debian-12-standard_12.2-1_amd64.tar.zst
```

### Dashboard Not Accessible

Check if service is running:
```bash
pct exec 105 -- systemctl status ingest-dashboard.service
```

Restart if needed:
```bash
pct exec 105 -- systemctl restart ingest-dashboard.service
```

Check firewall:
```bash
# On Proxmox host
iptables -L -n | grep 3000
```

### USB Not Detected

Verify udev rules:
```bash
cat /etc/udev/rules.d/99-ingest.rules
udevadm control --reload-rules
udevadm trigger
```

Test manually:
```bash
# Find USB device
lsblk

# Trigger manually
bash /usr/local/bin/usb-trigger.sh /dev/sdb
```

Check logs:
```bash
tail -f /var/log/usb-trigger.log
```

### Files Not Syncing

Check NAS mount inside container:
```bash
pct exec 105 -- df -h | grep nas
pct exec 105 -- ls -la /media/nas
```

Test rsync manually:
```bash
pct exec 105 -- rsync -rvh --progress /media/usb-ingest/Media/Movies/ /media/nas/Movies/
```

### Container Won't Start

Check container configuration:
```bash
cat /etc/pve/lxc/105.conf
```

Check logs:
```bash
journalctl -u pve-container@105 -n 50
```

---

## Updating

### Update Dashboard

```bash
pct exec 105 -- bash -c "cd /opt/dashboard && git pull && cd client && npm run build && systemctl restart ingest-dashboard.service"
```

### Update Ingest Script

```bash
wget http://192.168.1.14:3000/spooky/mediaingestDashboard/raw/branch/main/scripts/ingest-media.sh
pct push 105 ingest-media.sh /usr/local/bin/ingest-media.sh
pct exec 105 -- chmod +x /usr/local/bin/ingest-media.sh
```

### Update USB Trigger Script

```bash
wget http://192.168.1.14:3000/spooky/mediaingestDashboard/raw/branch/main/scripts/usb-trigger.sh
cp usb-trigger.sh /usr/local/bin/
chmod +x /usr/local/bin/usb-trigger.sh
# Update LXC_ID in the script if needed
sed -i 's/LXC_ID="105"/LXC_ID="YOUR_ID"/g' /usr/local/bin/usb-trigger.sh
```

---

## Uninstallation

### Remove Everything

```bash
# Stop and destroy container
pct stop 105
pct destroy 105

# Remove host scripts
rm /usr/local/bin/usb-trigger.sh
rm /etc/udev/rules.d/99-ingest.rules
udevadm control --reload-rules

# Remove logs
rm /var/log/usb-trigger.log
```

### Keep Container, Remove Dashboard Only

```bash
pct exec 105 -- systemctl stop ingest-dashboard.service
pct exec 105 -- systemctl disable ingest-dashboard.service
pct exec 105 -- rm -rf /opt/dashboard
pct exec 105 -- rm /etc/systemd/system/ingest-dashboard.service
pct exec 105 -- systemctl daemon-reload
```

---

## Manual Installation

If the automated installer doesn't work for your setup, see the [Full Deployment Guide](DEPLOYMENT_GUIDE.md) for step-by-step manual instructions.

---

## Security Notes

⚠️ **Important Security Considerations:**

1. **Root Access**: The installer requires root access to Proxmox
2. **Privileged Container**: Creates a privileged LXC for hardware access
3. **Network Exposure**: Dashboard runs on port 3000 (use firewall rules)
4. **Password**: Choose a strong password for the container
5. **Script Review**: Always review scripts before running as root

**Recommendations:**
- Run dashboard behind a reverse proxy with HTTPS
- Use firewall rules to restrict access
- Regularly update the system and dependencies
- Monitor logs for suspicious activity

---

## Getting Help

- 📖 [Full Deployment Guide](DEPLOYMENT_GUIDE.md) - Detailed manual setup
- 📖 [Scripts Documentation](scripts/README.md) - Script usage details
- 🐛 [Gitea Issues](http://192.168.1.14:3000/spooky/mediaingestDashboard/issues) - Report bugs
- 💬 [Gitea Repository](http://192.168.1.14:3000/spooky/mediaingestDashboard) - View source

---

**Installation Time:** ~5-10 minutes  
**Difficulty:** Easy (fully automated)  
**Skill Level:** Beginner-friendly
