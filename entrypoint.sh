#!/bin/sh
set -e

# Default to the built-in monero user's UID/GID; override for
# bind-mount/NAS setups where the data directory is owned elsewhere.
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Require non-interactive mode and bind the RPC safely.
#
# By default bind to loopback only, so a published port is NOT an
# unauthenticated wallet RPC (which could be used to open, create, or
# transfer funds). Exposing on 0.0.0.0 with --confirm-external-bind is only
# forced when a --rpc-login is configured (making the RPC authenticated) or
# when the operator explicitly opts out with RPC_EXPOSE_UNAUTHENTICATED=1.
has_rpc_login() {
    for arg in "$@"; do
        case "$arg" in
            --rpc-login|--rpc-login=*) return 0 ;;
        esac
    done
    return 1
}

if has_rpc_login "$@" || [ "${RPC_EXPOSE_UNAUTHENTICATED:-0}" = "1" ]; then
    set -- "monero-wallet-rpc" "--non-interactive" "--rpc-bind-ip=0.0.0.0" "--confirm-external-bind" "$@"
else
    set -- "monero-wallet-rpc" "--non-interactive" "--rpc-bind-ip=127.0.0.1" "$@"
fi

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
