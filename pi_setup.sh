#!/bin/bash

# Update and upgrade the system
sudo apt-get update && sudo apt-get upgrade -y

# Install unattended-upgrades for automatic updates
sudo apt-get install unattended-upgrades -y
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Configure automatic updates (using 'deb' instead of 'deb-src' to only download pre-built packages)
sudo bash -c 'cat <<EOT > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade-Package-Whitelisted-Updated "true";
APT::Periodic::Unattended-Upgrade-Package-Whitelisted-Installed "true";
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}";
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESM:${distro_codename}";
        "${distro_id}:${distro_codename}-updates";
};
EOT'

# Install and configure UFW firewall
sudo apt-get install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.54 to any port 22
sudo ufw allow from 192.168.1.54 to any port 9090
sudo ufw enable

# Install and configure fail2ban for IP banning
sudo apt-get install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure SSH to allow only from specific IP and disable root login
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo bash -c "echo 'AllowUsers pi@192.168.1.54' >> /etc/ssh/sshd_config"
sudo systemctl restart ssh

# Enable SSH for headless operation
sudo systemctl enable ssh
sudo systemctl start ssh

# Improve system performance by reducing swap usage (optional)
#sudo bash -c 'echo "vm.swappiness=10" >> /etc/sysctl.conf'
#sudo sysctl -p

# Run the second script
bash /path/to/your/prometheus_setup.sh