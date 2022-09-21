#!/bin/sh
# Credit for the bulk of this entrypoint script goes to cornfeedhobo
# Source is https://github.com/cornfeedhobo/docker-monero/blob/master/entrypoint.sh
set -e

# Set require --non-interactive flag
set -- "monero-wallet-rpc" "--non-interactive" "--rpc-bind-ip=0.0.0.0" "$@"

# Start the daemon using fixuid
# to adjust permissions if needed
exec fixuid -q "$@"
