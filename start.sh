#!/usr/bin/env bash

# If you are using VPNs, make sure you can use the tabby properly. This line disables 
# all active wireguard connections via NetworkManager.
nmcli c | grep wireguard | awk '{ print $1 }' | xargs -n 1 nmcli c down || true
nmcli c | grep wireguard | awk '{ print $1 }' | xargs -I {} -n 1 nmcli c mod {} connection.autoconnect false || true

terraform apply -auto-approve

