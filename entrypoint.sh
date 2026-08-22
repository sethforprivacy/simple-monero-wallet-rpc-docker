#!/bin/sh
set -e

# Default to the built-in monero user's UID/GID; override for
# bind-mount/NAS setups where the data directory is owned elsewhere.
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Require non-interactive mode and publish the RPC bind this image expects
set -- "monero-wallet-rpc" "--non-interactive" "--rpc-bind-ip=0.0.0.0" "--confirm-external-bind" "$@"

# When started as root (the image default), normalize ownership of the data
# and wallet directories for the requested UID/GID, then drop all
# privileges for the wallet process itself.
if [ "$(id -u)" = "0" ]; then
    if [ "$(stat -c %u /home/monero 2>/dev/null || echo "")" != "${PUID}" ] || \
       [ "$(stat -c %g /home/monero 2>/dev/null || echo "")" != "${PGID}" ]; then
        chown -R "${PUID}:${PGID}" /home/monero/.bitmonero /home/monero/wallet
    fi
    set -- su-exec "${PUID}:${PGID}" "$@"
fi

exec "$@"
