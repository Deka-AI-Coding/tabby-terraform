#!/usr/bin/env bash

# If you are using VPNs, make sure you can use the tabby properly. This line disables 
# all active wireguard connections via NetworkManager.
nmcli c | grep wireguard | awk '{ print $1 }' | xargs -n 1 nmcli c down || true

terraform apply -auto-approve

