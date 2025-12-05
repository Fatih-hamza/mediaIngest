#!/bin/bash

################################################################################
# Universal USB Media Ingest Installer for Proxmox VE
# 
# Features:
# - Intelligent destination selection (scans /mnt/pve/* and /mnt/*)
# - Interactive storage menu
# - Auto-provisions Media folder with proper permissions
# - Complete automation: Host + LXC creation + Dashboard
# - Single destination choice, then fully automated
################################################################################

set -e
set -o pipefail

################################################################################
# Color Definitions
################################################################################
BL='\033[36m'    # Blue
GN='\033[1;92m'  # Green
CL='\033[m'      # Clear
RD='\033[01;31m' # Red
YW='\033[1;33m'  # Yellow
MG='\033[35m'    # Magenta
CY='\033[96m'    # Cyan
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"

################################################################################
# Helper Functions
################################################################################
msg_info() {
    echo -ne " ${HOLD} ${YW}$1...${CL} "
}

msg_ok() {
    echo -e "${BFR} ${CM} ${GN}$1${CL}"
}

msg_error() {
    echo -e "${BFR} ${CROSS} ${RD}$1${CL}"
}

msg_warn() {
    echo -e " ${YW}⚠${CL} ${YW}$1${CL}"
}

header_info() {
    clear
    cat <<"EOF"
    __  ___          ___         ____                      __     _____            __               
   /  |/  /__  ____/ (_)___ _   /  _/___  ____ ____  _____/ /_   / ___/__  _______/ /____  ____ ___ 
  / /|_/ / _ \/ __  / / __ `/   / // __ \/ __ `/ _ \/ ___/ __/   \__ \/ / / / ___/ __/ _ \/ __ `__ \
 / /  / /  __/ /_/ / / /_/ /  _/ // / / / /_/ /  __(__  ) /_    ___/ / /_/ (__  ) /_/  __/ / / / / /
/_/  /_/\___/\__,_/_/\__,_/  /___/_/ /_/\__, /\___/____/\__/   /____/\__, /____/\__/\___/_/ /_/ /_/ 
                                       /____/                        /____/                          

                    Universal USB Media Ingest System
                    Intelligent Installer v3.0
                    

EOF
}

################################################################################
# Configuration Variables
################################################################################
CT_NAME="media-ingest"
CT_CORES=2
CT_MEMORY=2048
CT_SWAP=512
CT_DISK=8
CT_PASSWORD="mediaingest123"
USB_MOUNT="/mnt/usb-pass"
DEST_HOST_PATH=""      # Will be selected by user
DEST_LXC_PATH="/media/destination"
CONTAINER_EXISTS=false
CTID=""
STORAGE=""
TEMPLATE=""

################################################################################
# Validation Functions
################################################################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "This script must be run as root"
        echo -e "\nPlease run: ${GN}sudo bash install.sh${CL}\n"
        exit 1
    fi
}

check_proxmox() {
    if [ ! -f /etc/pve/.version ]; then
        msg_error "Proxmox VE not detected"
        echo -e "\nThis script must be run on a Proxmox VE host.\n"
        exit 1
    fi
    msg_ok "Proxmox VE detected"
}

################################################################################
# Destination Selection
################################################################################
scan_destinations() {
    echo -e "\n${BL}═══════════════════════════════════════════════════════════════${CL}"
    echo -e "${BL}              Scanning for Storage Destinations...              ${CL}"
    echo -e "${BL}═══════════════════════════════════════════════════════════════${CL}\n"
    
    # Find all mounted storage locations
    local destinations=()
    
    # Scan /mnt/pve/*
    if [ -d /mnt/pve ]; then
        while IFS= read -r dir; do
            if mountpoint -q "$dir" 2>/dev/null || [ -d "$dir" ]; then
                destinations+=("$dir")
            fi
        done < <(find /mnt/pve -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
    fi
    
    # Scan /mnt/* (exclude /mnt/pve and USB mount)
    while IFS= read -r dir; do
        if [ "$dir" != "/mnt/pve" ] && [ "$dir" != "$USB_MOUNT" ]; then
            if mountpoint -q "$dir" 2>/dev/null || [ -d "$dir" ]; then
                destinations+=("$dir")
            fi
        fi
    done < <(find /mnt -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
    
    if [ ${#destinations[@]} -eq 0 ]; then
        msg_error "No storage destinations found in /mnt/pve or /mnt"
        echo -e "\n${YW}Please ensure your NAS/storage is mounted first.${CL}\n"
        exit 1
    fi
    
    # Display menu
    echo -e "${GN}Available Storage Destinations:${CL}\n"
    for i in "${!destinations[@]}"; do
        local path="${destinations[$i]}"
        local size=$(df -h "$path" 2>/dev/null | awk 'NR==2 {print $2}' || echo "N/A")
        local used=$(df -h "$path" 2>/dev/null | awk 'NR==2 {print $3}' || echo "N/A")
        local avail=$(df -h "$path" 2>/dev/null | awk 'NR==2 {print $4}' || echo "N/A")
        printf "${CY}%2d)${CL} %-40s ${MG}Size:${CL} %-8s ${YW}Used:${CL} %-8s ${GN}Avail:${CL} %s\n" \
               "$((i+1))" "$path" "$size" "$used" "$avail"
    done
    
    echo ""
    while true; do
        read -p "$(echo -e ${GN}Select destination [1-${#destinations[@]}]:${CL} )" choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#destinations[@]}" ]; then
            DEST_HOST_PATH="${destinations[$((choice-1))]}"
            break
        else
            echo -e "${RD}Invalid choice. Please enter a number between 1 and ${#destinations[@]}${CL}"
        fi
    done
    
    msg_ok "Selected: $DEST_HOST_PATH"
}

provision_media_folder() {
    msg_info "Provisioning Media folder"
    
    local media_path="$DEST_HOST_PATH/Media"
    
    if [ ! -d "$media_path" ]; then
        mkdir -p "$media_path"
        chmod 777 "$media_path"
        msg_ok "Created: $media_path (permissions: 777)"
    else
        chmod 777 "$media_path"
        msg_ok "Media folder exists: $media_path (permissions updated)"
    fi
}

################################################################################
# Auto-Detection Functions
################################################################################
get_next_ctid() {
    msg_info "Auto-detecting next container ID"
    CTID=$(pvesh get /cluster/nextid)
    msg_ok "Container ID: $CTID"
}

detect_storage() {
    msg_info "Detecting available storage"
    
    # Prefer local-lvm, fallback to local
    if pvesm status | grep -q "local-lvm"; then
        STORAGE="local-lvm"
    elif pvesm status | grep -q "^local"; then
        STORAGE="local"
    else
        # Use first available storage
        STORAGE=$(pvesm status | awk 'NR==2 {print $1}')
    fi
    
    if [ -z "$STORAGE" ]; then
        msg_error "No storage found"
        exit 1
    fi
    
    msg_ok "Using storage: $STORAGE"
}

ensure_template() {
    msg_info "Checking for Debian 12 template"
    
    # Check if any Debian 12 template already exists
    if pveam list local 2>/dev/null | grep -q "debian-12"; then
        TEMPLATE=$(pveam list local | grep "debian-12" | head -1 | sed 's/.*vztmpl\///' | awk '{print $1}')
        msg_ok "Template found: $TEMPLATE"
        return
    fi
    
    msg_info "Downloading Debian 12 template"
    pveam update >/dev/null 2>&1 || msg_warn "Template list update had issues"
    
    # Auto-detect the latest available Debian 12 template
    TEMPLATE=$(pveam available | grep "debian-12-standard" | grep "amd64" | tail -1 | awk '{print $1}')
    
    if [ -z "$TEMPLATE" ]; then
        msg_error "No Debian 12 template found"
        exit 1
    fi
    
    echo -e "\n${BL}[INFO]${CL} Downloading $TEMPLATE (this may take 2-5 minutes)..."
    if pveam download local "$TEMPLATE"; then
        msg_ok "Template downloaded"
    else
        msg_error "Template download failed"
        exit 1
    fi
}

################################################################################
# Phase 1: Host Setup
################################################################################
setup_host_scripts() {
    echo -e "\n${BL}[Phase 1]${CL} Proxmox Host Configuration\n"
    
    msg_info "Creating USB trigger script"
    cat > /usr/local/bin/usb-trigger.sh << 'EOFSCRIPT'
#!/bin/bash

DEVICE=$1
LXC_ID=__LXC_ID__
MOUNT_POINT="/mnt/usb-pass"
LOG="/var/log/usb-ingest.log"

echo "$(date): USB device detected: $DEVICE" >> "$LOG"

# Unmount if already mounted
umount "$MOUNT_POINT" 2>/dev/null || true

# Try ntfs3 driver first (kernel 5.15+), fallback to ntfs-3g
if mount -t ntfs3 "${DEVICE}1" "$MOUNT_POINT" 2>/dev/null; then
    echo "$(date): Mounted with ntfs3 driver" >> "$LOG"
elif mount -t ntfs-3g "${DEVICE}1" "$MOUNT_POINT" 2>/dev/null; then
    echo "$(date): Mounted with ntfs-3g driver" >> "$LOG"
else
    echo "$(date): Mount failed for ${DEVICE}1" >> "$LOG"
    exit 1
fi

echo "$(date): Triggering ingest in LXC $LXC_ID" >> "$LOG"

# Execute ingest script inside LXC container
pct exec "$LXC_ID" -- /usr/local/bin/ingest-media.sh

echo "$(date): Ingest complete, unmounting USB" >> "$LOG"
umount "$MOUNT_POINT"
EOFSCRIPT
    
    chmod +x /usr/local/bin/usb-trigger.sh
    msg_ok "USB trigger script created"
    
    msg_info "Creating USB mount point"
    mkdir -p "$USB_MOUNT"
    msg_ok "Mount point $USB_MOUNT created"
    
    msg_info "Configuring udev rules"
    cat > /etc/udev/rules.d/99-usb-media-ingest.rules << 'EOF'
# Universal USB Media Ingest - Catch all USB storage devices
ACTION=="add", KERNEL=="sd[a-z]", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_BUS}=="usb", RUN+="/bin/bash -c '/usr/bin/systemd-run --no-block --unit=media-ingest-$kernel-$(date +%%s) /usr/local/bin/usb-trigger.sh /dev/$kernel'"
EOF
    
    udevadm control --reload-rules
    udevadm trigger
    msg_ok "udev rules configured"
}

################################################################################
# Phase 2: LXC Container Creation
################################################################################
create_container() {
    echo -e "\n${BL}[Phase 2]${CL} LXC Container Creation\n"
    
    # Check if container already exists
    if pct status $CTID &>/dev/null; then
        msg_warn "Container $CTID already exists, skipping creation"
        CONTAINER_EXISTS=true
        sed -i "s/__LXC_ID__/$CTID/g" /usr/local/bin/usb-trigger.sh 2>/dev/null || true
        return
    fi
    
    msg_info "Creating LXC container $CTID"
    echo -e "\n${BL}[INFO]${CL} This may take 30-60 seconds..."
    
    if pct create $CTID local:vztmpl/$TEMPLATE \
        --hostname $CT_NAME \
        --password "$CT_PASSWORD" \
        --cores $CT_CORES \
        --memory $CT_MEMORY \
        --swap $CT_SWAP \
        --rootfs $STORAGE:$CT_DISK \
        --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp \
        --features nesting=1,fuse=1 \
        --unprivileged 0 \
        --onboot 1 \
        --start 0; then
        msg_ok "Container $CTID created"
    else
        msg_error "Container creation failed"
        exit 1
    fi
    
    msg_info "Configuring bind mounts"
    # USB bind mount
    pct set $CTID -mp0 $USB_MOUNT,mp=/media/usb-ingest
    # Destination bind mount (user-selected path)
    pct set $CTID -mp1 "$DEST_HOST_PATH",mp="$DEST_LXC_PATH"
    msg_ok "Bind mounts configured"
    
    # Update usb-trigger.sh with actual container ID
    sed -i "s/__LXC_ID__/$CTID/g" /usr/local/bin/usb-trigger.sh
    
    msg_info "Starting container"
    pct start $CTID
    sleep 8
    msg_ok "Container started"
}

################################################################################
# Phase 3: Container Bootstrap
################################################################################
bootstrap_container() {
    echo -e "\n${BL}[Phase 3]${CL} Container Bootstrap\n"
    
    msg_info "Waiting for container to be ready"
    sleep 5
    msg_ok "Container ready"
    
    msg_info "Updating package lists"
    pct exec $CTID -- bash -c "apt-get update -qq" >/dev/null 2>&1
    msg_ok "Package lists updated"
    
    msg_info "Installing base dependencies"
    pct exec $CTID -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq rsync ntfs-3g python3 python3-pip curl >/dev/null 2>&1"
    msg_ok "Base dependencies installed"
    
    msg_info "Creating log file"
    pct exec $CTID -- bash -c "touch /var/log/media-ingest.log && chmod 644 /var/log/media-ingest.log"
    msg_ok "Log file created"
    
    msg_info "Deploying ingest script"
    pct exec $CTID -- bash -c "cat > /usr/local/bin/ingest-media.sh" << 'EOFSCRIPT'
#!/bin/bash

SEARCH_ROOT="/media/usb-ingest"
DEST_ROOT="/media/destination/Media"
LOG="/var/log/media-ingest.log"

echo "========================================" >> "$LOG"
echo "$(date): New Drive Detected. Scanning for Media folder..." >> "$LOG"

FOUND_SRC=$(find "$SEARCH_ROOT" -maxdepth 3 -type d -iname "Media" 2>/dev/null | head -n 1)

if [ -z "$FOUND_SRC" ]; then
    echo "Analysis: No Media folder found on this drive. Exiting." >> "$LOG"
    ls -F "$SEARCH_ROOT" >> "$LOG" 2>&1
    exit 0
fi

echo "Target Found: $FOUND_SRC" >> "$LOG"

sync_folder() {
    FOLDER_NAME=$1
    SRC_SUB=$(find "$FOUND_SRC" -maxdepth 1 -type d -iname "$FOLDER_NAME" 2>/dev/null | head -n 1)
    DST_PATH="$DEST_ROOT/$FOLDER_NAME"

    if [ -n "$SRC_SUB" ]; then
        echo "Syncing $SRC_SUB -> $DST_PATH" >> "$LOG"
        echo "SYNC_START:$FOLDER_NAME" >> "$LOG"

        stdbuf -oL rsync -rvh -W --inplace --progress --ignore-existing "$SRC_SUB/" "$DST_PATH/" 2>&1 | tr '\r' '\n' >> "$LOG"

        echo "SYNC_END:$FOLDER_NAME" >> "$LOG"
    else
        echo "Skipped: $FOLDER_NAME not found inside Media folder." >> "$LOG"
    fi
}

sync_folder "Movies"
sync_folder "Series"
sync_folder "Anime"

echo "$(date): Ingest Complete." >> "$LOG"
EOFSCRIPT
    
    pct exec $CTID -- chmod +x /usr/local/bin/ingest-media.sh
    msg_ok "Ingest script deployed"
}

################################################################################
# Phase 4: Python Dashboard Deployment
################################################################################
deploy_dashboard() {
    echo -e "\n${BL}[Phase 4]${CL} Dashboard Deployment\n"
    
    msg_info "Creating application directory"
    pct exec $CTID -- mkdir -p /opt/dashboard
    msg_ok "Application directory created"
    
    msg_info "Deploying Python dashboard"
    pct exec $CTID -- bash -c "cat > /opt/dashboard/dashboard.py" << 'EOFPYTHON'
#!/usr/bin/env python3
"""
Media Ingest Dashboard - Single File Python Web Application
Real-time monitoring of USB media ingest operations
"""

import http.server
import socketserver
import json
import os
import re
from datetime import datetime
from urllib.parse import urlparse, parse_qs

LOG_FILE = "/var/log/media-ingest.log"
PORT = 3000

class IngestDashboard(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/api/logs':
            self.serve_logs()
        elif parsed_path.path == '/api/status':
            self.serve_status()
        else:
            self.serve_dashboard()
    
    def serve_dashboard(self):
        """Serve the main HTML dashboard"""
        html = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Media Ingest Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #fff;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .status-bar {
            display: flex;
            gap: 20px;
            margin-bottom: 30px;
            flex-wrap: wrap;
        }
        .status-card {
            flex: 1;
            min-width: 200px;
            padding: 20px;
            background: rgba(255, 255, 255, 0.15);
            border-radius: 10px;
            backdrop-filter: blur(10px);
            text-align: center;
        }
        .status-card h3 {
            font-size: 0.9em;
            opacity: 0.8;
            margin-bottom: 10px;
        }
        .status-card .value {
            font-size: 2em;
            font-weight: bold;
        }
        .log-container {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 10px;
            padding: 20px;
            max-height: 600px;
            overflow-y: auto;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            line-height: 1.6;
        }
        .log-entry {
            padding: 8px;
            margin-bottom: 5px;
            border-left: 3px solid #4CAF50;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 3px;
        }
        .log-entry.sync-start {
            border-left-color: #2196F3;
            background: rgba(33, 150, 243, 0.1);
        }
        .log-entry.sync-end {
            border-left-color: #4CAF50;
            background: rgba(76, 175, 80, 0.1);
        }
        .log-entry.error {
            border-left-color: #f44336;
            background: rgba(244, 67, 54, 0.1);
        }
        .loading {
            text-align: center;
            padding: 40px;
            font-size: 1.2em;
            opacity: 0.7;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .pulse {
            animation: pulse 2s infinite;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📀 Media Ingest Dashboard</h1>
            <p>Real-time USB Media Transfer Monitor</p>
        </header>
        
        <div class="status-bar">
            <div class="status-card">
                <h3>Current Status</h3>
                <div class="value" id="status">IDLE</div>
            </div>
            <div class="status-card">
                <h3>Active Transfers</h3>
                <div class="value" id="activeTransfers">0</div>
            </div>
            <div class="status-card">
                <h3>Total Syncs</h3>
                <div class="value" id="totalSyncs">0</div>
            </div>
            <div class="status-card">
                <h3>Last Activity</h3>
                <div class="value" id="lastActivity" style="font-size: 1.2em;">Never</div>
            </div>
        </div>
        
        <div class="log-container" id="logContainer">
            <div class="loading pulse">Loading logs...</div>
        </div>
    </div>
    
    <script>
        let lastLogSize = 0;
        
        async function fetchLogs() {
            try {
                const response = await fetch('/api/logs');
                const data = await response.json();
                
                if (data.logs.length > 0) {
                    displayLogs(data.logs);
                    updateStatus(data);
                }
            } catch (error) {
                console.error('Error fetching logs:', error);
            }
        }
        
        function displayLogs(logs) {
            const container = document.getElementById('logContainer');
            container.innerHTML = logs.map(log => {
                let className = 'log-entry';
                if (log.includes('SYNC_START')) className += ' sync-start';
                if (log.includes('SYNC_END')) className += ' sync-end';
                if (log.includes('failed') || log.includes('error')) className += ' error';
                return `<div class="${className}">${escapeHtml(log)}</div>`;
            }).join('');
            container.scrollTop = container.scrollHeight;
        }
        
        function updateStatus(data) {
            const isSyncing = data.logs.some(log => 
                log.includes('SYNC_START') && 
                !data.logs.slice(data.logs.indexOf(log)).some(l => l.includes('SYNC_END'))
            );
            
            document.getElementById('status').textContent = isSyncing ? 'SYNCING' : 'IDLE';
            document.getElementById('status').style.color = isSyncing ? '#4CAF50' : '#FFC107';
            
            const syncStarts = data.logs.filter(log => log.includes('SYNC_START')).length;
            const syncEnds = data.logs.filter(log => log.includes('SYNC_END')).length;
            document.getElementById('activeTransfers').textContent = Math.max(0, syncStarts - syncEnds);
            document.getElementById('totalSyncs').textContent = syncEnds;
            
            if (data.logs.length > 0) {
                const lastLog = data.logs[data.logs.length - 1];
                const timeMatch = lastLog.match(/\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}/);
                if (timeMatch) {
                    document.getElementById('lastActivity').textContent = timeMatch[0].split(' ')[1];
                }
            }
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        // Fetch logs every 2 seconds
        setInterval(fetchLogs, 2000);
        fetchLogs(); // Initial fetch
    </script>
</body>
</html>"""
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def serve_logs(self):
        """Serve log data as JSON"""
        try:
            if os.path.exists(LOG_FILE):
                with open(LOG_FILE, 'r') as f:
                    logs = f.readlines()[-100:]  # Last 100 lines
                    logs = [log.strip() for log in logs if log.strip()]
            else:
                logs = ["Log file not found. Waiting for first USB ingest..."]
            
            data = {'logs': logs, 'count': len(logs)}
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
        except Exception as e:
            self.send_error(500, f"Error reading logs: {str(e)}")
    
    def serve_status(self):
        """Serve system status"""
        status = {
            'status': 'running',
            'log_file': LOG_FILE,
            'log_exists': os.path.exists(LOG_FILE)
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(status).encode())
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass

def main():
    with socketserver.TCPServer(("", PORT), IngestDashboard) as httpd:
        print(f"Dashboard running on port {PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    main()
EOFPYTHON
    
    pct exec $CTID -- chmod +x /opt/dashboard/dashboard.py
    msg_ok "Python dashboard deployed"
    
    msg_info "Creating systemd service"
    pct exec $CTID -- bash -c "cat > /etc/systemd/system/mediaingest-dashboard.service" << 'EOFSVC'
[Unit]
Description=Media Ingest Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/dashboard
ExecStart=/usr/bin/python3 /opt/dashboard/dashboard.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFSVC
    
    msg_ok "Systemd service created"
    
    msg_info "Starting dashboard service"
    pct exec $CTID -- systemctl daemon-reload
    pct exec $CTID -- systemctl enable mediaingest-dashboard.service >/dev/null 2>&1
    pct exec $CTID -- systemctl start mediaingest-dashboard.service
    sleep 3
    msg_ok "Dashboard service started"
}

################################################################################
# Summary
################################################################################
show_summary() {
    local IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
    
    echo -e "\n${GN}═══════════════════════════════════════════════════════════════${CL}"
    echo -e "${GN}            Installation Complete! 🎉                          ${CL}"
    echo -e "${GN}═══════════════════════════════════════════════════════════════${CL}\n"
    
    echo -e "${BL}Configuration Summary:${CL}"
    echo -e "  ${CY}Container ID:${CL}      $CTID"
    echo -e "  ${CY}Container Name:${CL}    $CT_NAME"
    echo -e "  ${CY}Password:${CL}          $CT_PASSWORD"
    echo -e "  ${CY}Dashboard URL:${CL}     ${GN}http://$IP:3000${CL}"
    echo ""
    echo -e "${BL}Storage Configuration:${CL}"
    echo -e "  ${CY}Host Path:${CL}         $DEST_HOST_PATH"
    echo -e "  ${CY}LXC Path:${CL}          $DEST_LXC_PATH"
    echo -e "  ${CY}Media Folder:${CL}      $DEST_HOST_PATH/Media"
    echo ""
    echo -e "${BL}How It Works:${CL}"
    echo -e "  1. Insert USB drive with a ${GN}Media${CL} folder"
    echo -e "  2. System auto-detects and mounts the USB"
    echo -e "  3. Syncs Movies, Series, Anime to: ${GN}$DEST_HOST_PATH/Media${CL}"
    echo -e "  4. Monitor progress at: ${GN}http://$IP:3000${CL}"
    echo ""
    echo -e "${BL}Useful Commands:${CL}"
    echo -e "  ${CY}View logs:${CL}         tail -f /var/log/media-ingest.log (in container)"
    echo -e "  ${CY}Access container:${CL}  pct enter $CTID"
    echo -e "  ${CY}Restart dashboard:${CL} pct exec $CTID -- systemctl restart mediaingest-dashboard"
    echo -e "  ${CY}Test USB trigger:${CL}  /usr/local/bin/usb-trigger.sh /dev/sdX"
    echo ""
    echo -e "${GN}Ready to ingest media! Insert a USB drive to begin.${CL}\n"
}

################################################################################
# Main Execution
################################################################################
main() {
    header_info
    echo -e "${GN}═══════════════════════════════════════════════════════════════${CL}"
    echo -e "${GN}     Intelligent Installer - Select Destination Once Only      ${CL}"
    echo -e "${GN}═══════════════════════════════════════════════════════════════${CL}\n"
    sleep 2
    
    # Validation
    check_root
    check_proxmox
    
    # User selects destination (ONLY user interaction)
    scan_destinations
    provision_media_folder
    
    echo -e "\n${GN}Starting automated installation...${CL}\n"
    sleep 2
    
    # Auto-Detection
    get_next_ctid
    detect_storage
    ensure_template
    
    # Phase 1: Host Setup
    setup_host_scripts
    
    # Phase 2: Container Creation
    create_container
    
    # Phase 3: Container Bootstrap
    bootstrap_container
    
    # Phase 4: Dashboard Deployment
    deploy_dashboard
    
    # Show Summary
    show_summary
}

# Cleanup on error
trap 'msg_error "Installation failed! Check the output above for errors."' ERR

# Run main function
main "$@"
