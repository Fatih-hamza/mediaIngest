# One-Line Installer

Deploy the entire Media Ingest System with a single command!

## Quick Install

### On Proxmox Host:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/YOUR_USERNAME/mediaingestDashboard/main/install.sh)"
```

Or using curl:
```bash
bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/mediaingestDashboard/main/install.sh)
```

### On LXC Container:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/YOUR_USERNAME/mediaingestDashboard/main/install.sh)"
```

---

## What It Does

The installer automatically detects your system type and performs the appropriate setup:

### Proxmox Host:
✅ Installs dependencies (curl, wget, ntfs-3g)  
✅ Downloads and installs `usb-trigger.sh`  
✅ Creates udev rule for USB auto-detection  
✅ Configures LXC bind mount  
✅ Prompts for LXC container ID  

### LXC Container:
✅ Installs Node.js 18.x  
✅ Installs rsync and dependencies  
✅ Downloads and installs `ingest-media.sh`  
✅ Clones dashboard repository  
✅ Installs backend dependencies  
✅ Builds frontend  
✅ Creates systemd service  
✅ Starts dashboard on port 3000  
✅ Configuration wizard for custom paths/folders  

---

## Installation Flow

1. **Run on Proxmox Host first:**
   - Sets up USB detection
   - Configures container bind mount
   - Prompts for LXC container ID

2. **Then run inside LXC Container:**
   - Installs complete dashboard
   - Starts service automatically
   - Shows access URL

---

## Interactive Configuration

The installer includes a configuration wizard that allows you to:

- Set custom NAS mount path (default: `/media/nas`)
- Set custom USB mount path (default: `/media/usb-ingest`)
- Add additional sync folders beyond Movies/Series/Anime

Example:
```
Configure now? [y/N]: y
NAS mount path [/media/nas]: /mnt/my-nas
USB mount path [/media/usb-ingest]: /media/usb
Add custom folders? (comma-separated): Documentaries,Music,Photos
```

---

## After Installation

### Access Dashboard:
```
http://YOUR_LXC_IP:3000
```

### Useful Commands:
```bash
# View logs
tail -f /var/log/media-ingest.log

# Service status
systemctl status mediaingest-dashboard.service

# Restart service
systemctl restart mediaingest-dashboard.service

# Test USB trigger (Proxmox)
bash /usr/local/bin/usb-trigger.sh /dev/sdb
```

---

## Troubleshooting

### Installer fails to download files:
- Check internet connection
- Verify GitHub/Gitea URL is accessible
- Try using curl instead of wget

### Service won't start:
```bash
journalctl -u mediaingest-dashboard.service -n 50 --no-pager
```

### USB not detected:
```bash
# Check udev rule
cat /etc/udev/rules.d/99-usb-media-ingest.rules

# Reload rules
udevadm control --reload-rules
```

---

## Manual Installation

If the one-line installer doesn't work, refer to the [full deployment guide](DEPLOYMENT_GUIDE.md).

---

## Requirements

- Proxmox VE 7.x or 8.x
- Debian 11/12 or Ubuntu 22.04 LXC container
- Root/sudo access
- Internet connection

---

## Security Note

⚠️ This installer runs as root and downloads scripts from the internet. Review the [install.sh](install.sh) source code before running if you have security concerns.

---

## Updating

To update an existing installation:

```bash
# On LXC container
cd /root/ingestMonitor/mediaingestDashboard
git pull
cd client && npm run build && cd ..
systemctl restart mediaingest-dashboard.service
```

---

## Uninstall

```bash
# On Proxmox
rm /usr/local/bin/usb-trigger.sh
rm /etc/udev/rules.d/99-usb-media-ingest.rules
udevadm control --reload-rules

# On LXC
systemctl stop mediaingest-dashboard.service
systemctl disable mediaingest-dashboard.service
rm /etc/systemd/system/mediaingest-dashboard.service
rm -rf /root/ingestMonitor/mediaingestDashboard
rm /usr/local/bin/ingest-media.sh
rm /var/log/media-ingest.log
```
