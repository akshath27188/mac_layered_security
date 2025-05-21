#!/bin/bash

echo "🔧 Installing Suricata, Promtail, Loki, and Grafana..."

brew install suricata promtail loki grafana

RULE_DIR="/opt/homebrew/etc/suricata/rules"
CONFIG_FILE="/opt/homebrew/etc/suricata/suricata.yaml"
EVE_LOG="/opt/homebrew/etc/suricata/eve.json"

mkdir -p "$RULE_DIR"
cat <<EOF > "$RULE_DIR/local.rules"
alert tcp any any -> $HOME_NET any (msg:"Potential TCP Port Scan"; flags:S; threshold: type both, track by_src, count 20, seconds 10; classtype:attempted-recon; sid:9999999; rev:1;)
EOF

sed -i '' 's|default-rule-path:.*|default-rule-path: /opt/homebrew/etc/suricata/rules|' "$CONFIG_FILE"
if ! grep -q "local.rules" "$CONFIG_FILE"; then
  sed -i '' '/rule-files:/a\
  - local.rules
' "$CONFIG_FILE"
fi

echo "🚨 Starting Suricata..."
sudo suricata -c "$CONFIG_FILE" -i en0 &

cat <<EOF > loki-config.yaml
auth_enabled: false
server:
  http_listen_port: 3100
common:
  instance_addr: 127.0.0.1
  path_prefix: /opt/homebrew/var/loki
  storage:
    filesystem:
      chunks_directory: /opt/homebrew/var/loki/chunks
      rules_directory: /opt/homebrew/var/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
schema_config:
  configs:
    - from: 2022-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v12
      index:
        prefix: index_
        period: 24h
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF

loki -config.file=loki-config.yaml &

cat <<EOF > promtail-config.yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: suricata
    static_configs:
      - targets:
          - localhost
        labels:
          job: suricata
          __path__: $EVE_LOG
EOF

promtail --config.file=promtail-config.yaml &

echo "📊 Starting Grafana..."
brew services start grafana

echo "✅ Setup complete. Visit Grafana at http://localhost:3000"
