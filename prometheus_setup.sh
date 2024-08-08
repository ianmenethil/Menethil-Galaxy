prometheus_setup.sh#!/bin/bash

# Install Prometheus dependencies
sudo apt-get update -y
sudo apt-get install wget curl -y

# Install Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-armv7.tar.gz
tar xvf prometheus-2.40.0.linux-armv7.tar.gz
sudo mv prometheus-2.40.0.linux-armv7 /usr/local/prometheus

# Create Prometheus user and directories
sudo useradd -M -r -s /bin/false prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/prometheus /etc/prometheus /var/lib/prometheus

# Create Prometheus configuration file
sudo bash -c 'cat <<EOT > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOT'

# Create Prometheus service file
sudo bash -c 'cat <<EOT > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
User=prometheus
Restart=on-failure
ExecStart=/usr/local/prometheus/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus/ \\
  --web.listen-address=192.168.1.54:9090

[Install]
WantedBy=multi-user.target
EOT'

# Reload systemd, enable and start Prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Install Node Exporter
sudo useradd -rs /bin/false node_exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-armv7.tar.gz
tar xvf node_exporter-1.5.0.linux-armv7.tar.gz
sudo mv node_exporter-1.5.0.linux-armv7 /usr/local/bin/node_exporter

# Create Node Exporter service file
sudo bash -c 'cat <<EOT > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOT'

# Reload systemd, enable and start Node Exporter
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter