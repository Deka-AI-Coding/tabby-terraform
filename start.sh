#!/usr/bin/env bash

# If using are VPNs you need to disable it or configure it first.
nmcli c | grep wireguard | awk '{ print $1 }' | xargs -n 1 nmcli c down || true

terraform apply -auto-approve

