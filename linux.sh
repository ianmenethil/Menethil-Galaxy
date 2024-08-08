#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Logging function
log() {
    echo "[$(date +"%Y-%m-%d %T")] $1" | tee -a "/var/log/server_hardening.log"
}

error_exit() {
    log "$1"
    exit 1
}

backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "$file.bak"
        log "Backup of $file created."
    else
        log "Backup of $file failed; file does not exist."
    fi
}

# Retrieve and display current username and user rights
current_user=$(whoami)
log "Current user is: $current_user"

user_capabilities=$(groups $current_user)
log "User capabilities: $user_capabilities"

# Check if the user is root or not
if [ $current_user == "root" ]; then
    log "User is root"
else
    log "User is not root"
fi

# Add the user to sudo group if not root
if [ $current_user != "root" ]; then
    log "Adding user to sudo group"
    usermod -aG sudo $current_user
fi

# Update the system
log "Updating the system"
apt update -y && apt upgrade -y || error_exit "Failed to update the system."

# Add environment variables to .bashrc
log "Setting environment variables"
echo "export PATH=\$PATH:/home/$current_user/.local/bin" >> /home/$current_user/.bashrc
echo "export AIDER_35TURBO=true" >> /home/$current_user/.bashrc

# Install essential security packages
log "Installing essential security packages..."
apt install -y ufw fail2ban unattended-upgrades apt-listchanges auditd xrdp || error_exit "Failed to install security packages."

# Enable automatic security updates
log "Enabling automatic security updates..."
dpkg-reconfigure -plow unattended-upgrades

# Set up UFW firewall
log "Setting up UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.1.54 to any port 3389 proto tcp # Allow RDP from specific IPv4
ufw allow from 192.168.1.54 to any port 5900 proto tcp # Allow VNC from specific IPv4
ufw allow from fe80::/64 to any port 3389 proto tcp # Allow RDP from specific IPv6 range
ufw allow from fe80::/64 to any port 5900 proto tcp # Allow VNC from specific IPv6 range
ufw enable || error_exit "Failed to configure UFW."

# Configure XRDP for remote desktop access
log "Configuring XRDP..."
systemctl enable xrdp
systemctl start xrdp

# Create user 'cae' if not exists and configure SSH
if id "cae" &>/dev/null; then
    log "User 'cae' already exists."
else
    log "Creating user 'cae'..."
    adduser cae && usermod -aG sudo cae || error_exit "Failed to create user 'cae'."
fi

log "Configuring SSH..."
backup_file /etc/ssh/sshd_config
sed -i 's/^#*\(Port\) .*/\1 8090/' /etc/ssh/sshd_config &&
sed -i 's/^#*\(PermitRootLogin\) .*/\1 no/' /etc/ssh/sshd_config &&
sed -i 's/^#*\(PasswordAuthentication\) .*/\1 no/' /etc/ssh/sshd_config &&
sed -i 's/^#*\(AllowUsers\) .*/\1 cae/' /etc/ssh/sshd_config &&
systemctl restart sshd || error_exit "Failed to configure SSH."

# Set up Fail2Ban for SSH protection
log "Setting up Fail2Ban for SSH protection..."
systemctl enable fail2ban && systemctl start fail2ban || error_exit "Failed to start or enable Fail2Ban."

# Install and configure auditd for auditing
log "Installing and configuring auditd..."
auditctl -e 1 || error_exit "Failed to configure auditd."

# Disable root login
log "Disabling root login..."
passwd -l root || error_exit "Failed to disable root login."

# Disable unused filesystems for added security
log "Disabling unused filesystems..."
cat >>/etc/modprobe.d/hardening.conf <<EOF
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
EOF
log "Unused filesystems disabled."

# Disable uncommon network protocols
log "Disabling uncommon network protocols..."
cat >>/etc/modprobe.d/hardening.conf <<EOF
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF
log "Uncommon network protocols disabled."

# Ensure permissions on sensitive files
log "Securing permissions on sensitive files..."
chmod 600 /etc/crontab
chmod 600 /etc/ssh/sshd_config
chmod 700 /root
log "Permissions secured."

# Secure shared memory
log "Securing shared memory..."
echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >>/etc/fstab
log "Shared memory secured."

# Install and configure AIDE
log "Installing and configuring AIDE..."
apt install -y aide && aideinit
log "AIDE installed and initialized."

# System optimization and cleanup
log "Removing unnecessary packages and cleaning up..."
apt autoremove -y && apt autoclean -y
log "System optimized and cleaned up."

# Schedule weekly reboot
log "Scheduling weekly reboot..."
echo "0 3 * * 0 root /sbin/shutdown -r now" > /etc/cron.d/weekly-reboot

log "Server hardening and user setup process completed."
