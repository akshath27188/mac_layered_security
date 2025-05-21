#!/bin/bash

echo "🛑 Stopping all services..."
brew services stop suricata
brew services stop grafana
brew services stop loki
pkill promtail 2>/dev/null || echo "Promtail was not running."

echo "🗑 Uninstalling packages..."
brew uninstall suricata promtail loki grafana

echo "🧼 Cleaning up configuration files..."
sudo rm -rf /opt/homebrew/etc/suricata
sudo rm -rf /opt/homebrew/var/log/suricata
sudo rm -rf /opt/homebrew/var/loki
rm -f loki-config.yaml promtail-config.yaml /tmp/positions.yaml

echo "✅ Uninstall complete."
