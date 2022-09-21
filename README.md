# simple-monero-wallet-rpc-docker

A simple and straightforward Dockerized monerod built from source and exposing standard ports.

## Actions

[![Weekly Update Rebuild](https://github.com/sethsimmons/simple-monero-wallet-rpc-docker/actions/workflows/update-base-image.yml/badge.svg)](https://github.com/sethsimmons/simple-monero-wallet-rpc-docker/actions/workflows/update-base-image.yml) 
[![Latest Dockerfile build](https://github.com/sethsimmons/simple-monero-wallet-rpc-docker/actions/workflows/update-image-on-push.yml/badge.svg)](https://github.com/sethsimmons/simple-monero-wallet-rpc-docker/actions/workflows/update-image-on-push.yml)  
[![Container security scan with Trivy](https://github.com/sethsimmons/simple-monero-wallet-rpc-docker/actions/workflows/trivy-analysis.yml/badge.svg)](https://github.com/sethsimmons/simple-monero-wallet-rpc-docker/actions/workflows/trivy-analysis.yml)

## Docker

![Docker Pulls](https://img.shields.io/docker/pulls/sethsimmons/simple-monero-wallet-rpc)  
![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/sethsimmons/simple-monero-wallet-rpc)  
![Docker Image Version (latest by date)](https://img.shields.io/docker/v/sethsimmons/simple-monero-wallet-rpc)  

## Docker Hub

This repo is used to build the images available at:

https://hub.docker.com/r/sethsimmons/simple-monero-wallet-rpc

## Tags

I will always release the latest Monero version under the `latest` tag as well as the version number tag (i.e. `v0.18.1.1`).

`latest`: The latest tagged version of Monero from https://github.com/monero-project/monero/tags  
`vx.xx.x.x`: The version corresponding with the tagged version from https://github.com/monero-project/monero/tags

## Recommended usage

```bash
sudo docker run -d --restart unless-stopped --name="monero-wallet-rpc" -v monero-wallet-rpc-data:/home/monero sethsimmons/simple-monero-wallet-rpc:latest --daemon-host 127.0.0.1:18089 --rpc-bind-port 18083 --disable-rpc-login --trusted-daemon
```

## Copyrights

Code from this repository is released under MIT license. [Monero License](https://github.com/monero-project/monero/blob/master/LICENSE), [@leonardochaia License](https://github.com/leonardochaia/docker-monerod/blob/master/LICENSE)

## Copyrights

Code from this repository is released under MIT license. [Monero License](https://github.com/monero-project/monero/blob/master/LICENSE), [@leonardochaia License](https://github.com/leonardochaia/docker-monerod/blob/master/LICENSE)

## Credits

The base for the Dockerfile was pulled from:

https://github.com/leonardochaia/docker-monerod

The migration to Alpine from a Ubuntu 20.04 base image was based largely on previous commits from:

https://github.com/cornfeedhobo/docker-monero
