# veil-node-installer

A one-shot installer for Veil. https://veil-project.com/ The first Zerocoin-based cryptocurrency with always-on privacy.

## How to build and run a veil node from source

Easy. No options, just run `install.sh` after cloning the repo:

`git clone https://github.com/marsmensch/veil-node-installer.git && cd veil-node-installer && ./install.sh`

Start the node:
`/usr/local/bin/start_veil_node`

## What happens behind the scenes?

Compiles the desired Veil version from source and takes care of the following tasks for you

* 100% auto-compilation and configuration. 
* Developed with recent Ubuntu versions in mind, tested and built on 18.04 LTS 
* Installs 1 Veil node per system
* Some security hardening is done, including firewalling and a separate user
* Automatic startup for all masternode daemons
* This script needs to run as root, the nodes will not
