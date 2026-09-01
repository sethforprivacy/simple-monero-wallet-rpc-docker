# simple-monero-wallet-rpc-docker

A simple and straightforward Dockerized monero-wallet-rpc built from source and exposing standard ports.

## Tags

I will always release the latest Monero version under the `latest` tag as well as the version number tag (i.e. `v0.18.4.4`).

`latest`: The latest tagged version of Monero from https://github.com/monero-project/monero/tags  
`vx.xx.x.x`: The version corresponding with the tagged version from https://github.com/monero-project/monero/tags

## Recommended usage

```bash
sudo docker run -d --restart unless-stopped --name="monero-wallet-rpc" -v monero-wallet-rpc-data:/home/monero ghcr.io/sethforprivacy/simple-monero-wallet-rpc:latest --daemon-host 127.0.0.1:18089 --rpc-bind-port 18083 --rpc-login username:password --trusted-daemon
```

## Security: Docker port publishing (0.0.0.0) and UFW

Docker publishes ports on all interfaces by default. If you use `-p` with `docker run` (for example, `-p 18083:18083`) or define `ports:` in `docker-compose.yml` (for example, `- 18083:18083`), Docker binds those ports to `0.0.0.0` unless you explicitly specify a host IP. This makes the service reachable from any network interface on the host.

This can also bypass UFW rules. Docker installs its own iptables rules that accept traffic to published ports before UFW's filter rules are evaluated. As a result, even if UFW's default policy is to deny incoming traffic, a published Docker port may still be reachable from the internet.

`monero-wallet-rpc` can open, create, and transfer funds from any wallet in its wallet directory, so it must never be exposed without authentication:

- By default this image binds the RPC to `127.0.0.1` (loopback) and does not pass `--confirm-external-bind`, so a published port with no `--rpc-login` configured still only serves loopback traffic. Keep your daemon and app on the same host.
- To expose the RPC beyond the host you MUST configure `--rpc-login username:password`; the entrypoint then binds to `0.0.0.0` with `--confirm-external-bind`, keeping the port authenticated.
- If you deliberately want an unauthenticated RPC reachable outside the host, set `RPC_EXPOSE_UNAUTHENTICATED=1` to force `0.0.0.0` — this is strongly discouraged.
- Regardless of bind address, prefer binding published ports only to loopback: `-p 127.0.0.1:18083:18083` or `ports: ["127.0.0.1:18083:18083"]`.

## Running as a different user

The container starts as root only briefly: the entrypoint normalizes ownership of the data and wallet directories, then drops all privileges and runs the wallet via [su-exec](https://github.com/ncopa/su-exec). By default it runs as UID/GID 1000 (the built-in `monero` user).

To run as a different UID/GID — for example when the wallet directory lives on an NFS mount or a NAS owned by another host user — set the `PUID` and `PGID` environment variables:

```yaml
environment:
  - PUID=1001
  - PGID=1001
```

Unlike the previous fixuid-based setup, the image contains no setuid binaries and is compatible with `security-opt: ["no-new-privileges:true"]`.

## Copyrights

Code from this repository is released under MIT license. [Monero License](https://github.com/monero-project/monero/blob/master/LICENSE), [@leonardochaia License](https://github.com/leonardochaia/docker-monerod/blob/master/LICENSE)

## Credits

The base for the Dockerfile was pulled from:

https://github.com/leonardochaia/docker-monerod

The migration to Alpine from a Ubuntu 20.04 base image was based largely on previous commits from:

https://github.com/cornfeedhobo/docker-monero
