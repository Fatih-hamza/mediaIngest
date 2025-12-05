#!/bin/bash

#############################################
# Media Ingest System - One-Line Installer
# Automated deployment for Proxmox + LXC
#############################################

set -e

REPO_URL="https://raw.githubusercontent.com/YOUR_USERNAME/mediaingestDashboard/main"
SCRIPTS_DIR="/usr/local/bin"
SYSTEM_TYPE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
show_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║      Media Ingest System - Automated Installer       ║
║                                                       ║
║      USB → Proxmox → LXC → NAS Automation            ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Detect system type
detect_system() {
    log_info "Detecting system type..."
    
    if [ -f /etc/pve/.version ]; then
        SYSTEM_TYPE="proxmox"
        log_success "Detected: Proxmox VE Host"
    elif [ -f /etc/debian_version ] && ! [ -f /etc/pve/.version ]; then
        if systemd-detect-virt -c &>/dev/null; then
            SYSTEM_TYPE="lxc"
            log_success "Detected: LXC Container"
        else
            SYSTEM_TYPE="debian"
            log_success "Detected: Debian/Ubuntu System"
        fi
    else
        log_error "Unsupported system. This installer requires Proxmox VE or Debian/Ubuntu."
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."
    
    apt-get update -qq
    
    if [ "$SYSTEM_TYPE" = "proxmox" ]; then
        apt-get install -y -qq curl wget ntfs-3g
        log_success "Proxmox dependencies installed"
    elif [ "$SYSTEM_TYPE" = "lxc" ]; then
        apt-get install -y -qq curl wget git rsync ntfs-3g nodejs npm
        log_success "LXC dependencies installed"
    fi
}

# Proxmox Host Setup
setup_proxmox_host() {
    log_info "Setting up Proxmox host..."
    
    # Get LXC container ID
    echo ""
    read -p "Enter LXC Container ID (e.g., 105): " LXC_ID
    
    if [ -z "$LXC_ID" ]; then
        log_error "LXC ID cannot be empty"
        exit 1
    fi
    
    # Verify container exists
    if ! pct status "$LXC_ID" &>/dev/null; then
        log_error "LXC container $LXC_ID does not exist"
        exit 1
    fi
    
    log_info "Using LXC Container ID: $LXC_ID"
    
    # Create mount point
    mkdir -p /mnt/usb-pass
    log_success "Created USB mount point: /mnt/usb-pass"
    
    # Download usb-trigger.sh
    log_info "Downloading usb-trigger.sh script..."
    curl -sL "$REPO_URL/scripts/usb-trigger.sh" -o "$SCRIPTS_DIR/usb-trigger.sh"
    
    # Update LXC_ID in script
    sed -i "s/LXC_ID=\"105\"/LXC_ID=\"$LXC_ID\"/g" "$SCRIPTS_DIR/usb-trigger.sh"
    chmod +x "$SCRIPTS_DIR/usb-trigger.sh"
    log_success "Installed: $SCRIPTS_DIR/usb-trigger.sh"
    
    # Create udev rule
    log_info "Creating udev rule for USB detection..."
    cat > /etc/udev/rules.d/99-usb-media-ingest.rules << 'EOF'
# USB Media Ingest Trigger
ACTION=="add", KERNEL=="sd[a-z]", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_BUS}=="usb", RUN+="/bin/bash -c \"/usr/bin/systemd-run --no-block --unit=media-ingest-$kernel-$(date +%%s) /usr/local/bin/usb-trigger.sh /dev/$kernel\""
EOF
    
    udevadm control --reload-rules
    udevadm trigger
    log_success "udev rule installed and activated"
    
    # Configure LXC bind mount
    log_info "Configuring LXC bind mount..."
    if ! grep -q "mp1.*usb-pass" /etc/pve/lxc/$LXC_ID.conf; then
        echo "mp1: /mnt/usb-pass,mp=/media/usb-ingest" >> /etc/pve/lxc/$LXC_ID.conf
        log_success "Added bind mount to LXC configuration"
    else
        log_warning "Bind mount already exists in LXC configuration"
    fi
    
    echo ""
    log_success "Proxmox host setup complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Run this installer inside LXC container $LXC_ID"
    echo "  2. Command: pct enter $LXC_ID"
    echo "  3. Then run: bash <(wget -qO- $REPO_URL/install.sh)"
    echo ""
}

# LXC Container Setup
setup_lxc_container() {
    log_info "Setting up LXC container..."
    
    # Create directories
    mkdir -p /root/ingestMonitor
    mkdir -p /media/usb-ingest
    mkdir -p /media/nas
    log_success "Created directories"
    
    # Install Node.js if not present
    if ! command -v node &>/dev/null; then
        log_info "Installing Node.js 18.x..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
        log_success "Node.js installed: $(node --version)"
    else
        log_success "Node.js already installed: $(node --version)"
    fi
    
    # Download ingest-media.sh
    log_info "Downloading ingest-media.sh script..."
    curl -sL "$REPO_URL/scripts/ingest-media.sh" -o "$SCRIPTS_DIR/ingest-media.sh"
    chmod +x "$SCRIPTS_DIR/ingest-media.sh"
    log_success "Installed: $SCRIPTS_DIR/ingest-media.sh"
    
    # Create log file
    touch /var/log/media-ingest.log
    log_success "Created log file: /var/log/media-ingest.log"
    
    # Clone or download dashboard
    log_info "Setting up dashboard application..."
    cd /root/ingestMonitor
    
    if [ -d "mediaingestDashboard" ]; then
        log_warning "Dashboard directory exists, updating..."
        cd mediaingestDashboard
        if [ -d ".git" ]; then
            git pull
        fi
    else
        log_info "Cloning dashboard repository..."
        # Try git clone first, fall back to downloading files
        if git clone https://github.com/YOUR_USERNAME/mediaingestDashboard.git 2>/dev/null; then
            cd mediaingestDashboard
        else
            log_warning "Git clone failed, downloading files manually..."
            mkdir -p mediaingestDashboard
            cd mediaingestDashboard
            
            # Download essential files
            curl -sL "$REPO_URL/server.js" -o server.js
            curl -sL "$REPO_URL/package.json" -o package.json
            
            mkdir -p client/src
            curl -sL "$REPO_URL/client/package.json" -o client/package.json
            curl -sL "$REPO_URL/client/index.html" -o client/index.html
            curl -sL "$REPO_URL/client/vite.config.js" -o client/vite.config.js
            curl -sL "$REPO_URL/client/tailwind.config.js" -o client/tailwind.config.js
            curl -sL "$REPO_URL/client/postcss.config.js" -o client/postcss.config.js
            curl -sL "$REPO_URL/client/src/App.jsx" -o client/src/App.jsx
            curl -sL "$REPO_URL/client/src/main.jsx" -o client/src/main.jsx
            curl -sL "$REPO_URL/client/src/index.css" -o client/src/index.css
        fi
    fi
    
    # Install backend dependencies
    log_info "Installing backend dependencies..."
    npm install --silent
    log_success "Backend dependencies installed"
    
    # Build frontend
    log_info "Building frontend..."
    cd client
    npm install --silent
    npm run build
    log_success "Frontend built successfully"
    cd ..
    
    # Create systemd service
    log_info "Creating systemd service..."
    cat > /etc/systemd/system/mediaingest-dashboard.service << 'EOF'
[Unit]
Description=Media Ingest Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/ingestMonitor/mediaingestDashboard
ExecStart=/usr/bin/node /root/ingestMonitor/mediaingestDashboard/server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable mediaingest-dashboard.service
    systemctl start mediaingest-dashboard.service
    log_success "Dashboard service installed and started"
    
    # Check service status
    sleep 2
    if systemctl is-active --quiet mediaingest-dashboard.service; then
        log_success "Dashboard service is running!"
    else
        log_error "Dashboard service failed to start"
        log_info "Check logs with: journalctl -u mediaingest-dashboard.service -n 50"
    fi
    
    # Get IP address
    IP_ADDR=$(hostname -I | awk '{print $1}')
    
    echo ""
    log_success "LXC container setup complete!"
    echo ""
    log_info "Access your dashboard at:"
    echo -e "  ${GREEN}http://$IP_ADDR:3000${NC}"
    echo ""
    log_info "Useful commands:"
    echo "  - View logs: tail -f /var/log/media-ingest.log"
    echo "  - Service status: systemctl status mediaingest-dashboard.service"
    echo "  - Restart service: systemctl restart mediaingest-dashboard.service"
    echo ""
}

# Configuration wizard
configuration_wizard() {
    echo ""
    log_info "Would you like to configure mount points? (NAS path, USB path, folder names)"
    read -p "Configure now? [y/N]: " configure
    
    if [[ "$configure" =~ ^[Yy]$ ]]; then
        echo ""
        read -p "NAS mount path [/media/nas]: " nas_path
        nas_path=${nas_path:-/media/nas}
        
        read -p "USB mount path [/media/usb-ingest]: " usb_path
        usb_path=${usb_path:-/media/usb-ingest}
        
        log_info "Updating paths in ingest-media.sh..."
        sed -i "s|DEST_ROOT=\"/media/nas\"|DEST_ROOT=\"$nas_path\"|g" "$SCRIPTS_DIR/ingest-media.sh"
        sed -i "s|SEARCH_ROOT=\"/media/usb-ingest\"|SEARCH_ROOT=\"$usb_path\"|g" "$SCRIPTS_DIR/ingest-media.sh"
        
        log_success "Configuration updated"
        
        echo ""
        log_info "Default folder sync: Movies, Series, Anime"
        read -p "Add custom folders? (comma-separated, e.g., Documentaries,Music): " custom_folders
        
        if [ -n "$custom_folders" ]; then
            IFS=',' read -ra FOLDERS <<< "$custom_folders"
            for folder in "${FOLDERS[@]}"; do
                folder=$(echo "$folder" | xargs) # trim whitespace
                echo "sync_folder \"$folder\"" >> "$SCRIPTS_DIR/ingest-media.sh"
                log_success "Added folder: $folder"
            done
        fi
    fi
}

# Main installation
main() {
    show_banner
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This installer must be run as root"
        exit 1
    fi
    
    detect_system
    install_dependencies
    
    if [ "$SYSTEM_TYPE" = "proxmox" ]; then
        setup_proxmox_host
    elif [ "$SYSTEM_TYPE" = "lxc" ] || [ "$SYSTEM_TYPE" = "debian" ]; then
        setup_lxc_container
        configuration_wizard
    fi
    
    echo ""
    log_success "═══════════════════════════════════════════════════════"
    log_success "  Media Ingest System installation complete!"
    log_success "═══════════════════════════════════════════════════════"
    echo ""
}

# Run main function
main "$@"
