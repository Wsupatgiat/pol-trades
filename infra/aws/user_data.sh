#!/bin/bash
# First-boot setup for the Airflow EC2 instance. Runs once as root via cloud-init.
# Output: /var/log/cloud-init-output.log
set -euo pipefail

# Docker and the Astro CLI (pinned to the version used locally)
apt-get update
apt-get install -y docker.io docker-compose-v2 docker-buildx git
usermod -aG docker ubuntu
curl -sSL install.astronomer.io | ASTRO_INSTALL_DIR=/usr/local/bin bash -s -- v1.45.0

# repo and a secret-free .env that points Airflow at the SSM secrets backend
sudo -u ubuntu git clone https://github.com/Wsupatgiat/pol-trades.git /home/ubuntu/pol-trades
sudo -u ubuntu tee /home/ubuntu/pol-trades/.env > /dev/null <<'EOF'
AIRFLOW__SECRETS__BACKEND=airflow.providers.amazon.aws.secrets.systems_manager.SystemsManagerParameterStoreBackend
AIRFLOW__SECRETS__BACKEND_KWARGS={"connections_prefix": "/pol-trades/airflow/connections", "variables_prefix": null, "config_prefix": null}
AWS_DEFAULT_REGION=us-east-1
EOF

# systemd service so Airflow starts now and on every boot
cat > /etc/systemd/system/airflow.service <<'EOF'
[Unit]
Description=Airflow (astro dev)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=ubuntu
WorkingDirectory=/home/ubuntu/pol-trades
ExecStart=/usr/local/bin/astro dev start --no-browser
ExecStop=/usr/local/bin/astro dev stop

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now --no-block airflow.service
