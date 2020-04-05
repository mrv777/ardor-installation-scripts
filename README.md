# Ardor Installation Scripts

Repository for [Ardor](https://ardorplatform.org) node installation scripts for Debian based servers.

## Features
- Download Ardor software
- Download and install Java
- Option to install Ardor mainnet and/or testnet
- Option to download blockchain snapshot for fast syncing
- Option to enable Open API setting on node(s)
- Option to enable the node(s) as archive
- Setup service to automatically start Ardor after a reboot and run it in the background
- If the server has a domain name, option to setup and enable https access
- Option for daily automatic update check/install
- Option for monthly database optimizations

## Getting Started

If you only have a root user or are unsure, start here
``wget https://raw.githubusercontent.com/mrv777/ardor-installation-scripts/master/create-sudo-user.sh``

``bash ./create-sudo-user.sh -u {username} -p {password}``
Remove the {username} with your username and the same for password

Logout and log back in as new user
Now that we have a regular user we can do the 2 commands to get and set everthing up:
``wget https://raw.githubusercontent.com/mrv777/ardor-installation-scripts/master/install-ardor.sh``
``bash ./install-ardor.sh``

## Files
### install-ardor.sh

This is the *main* script. It installs, creates and configures all necessary parts to run an Ardor node. You can install an Ardor mainnet node, testnet node or both on one server. If you want to install https for both, make sure that the server is accessible via two seperate domains.

It also installs an **update-nodes.sh** script on the server, which can be used to easily update the nodes in case of a new Ardor release. It downloads, stops, updates and restarts the node(s) by itself.  If you selected to enable automatic updates, a cronjob is created to run this daily at 02:00.
It also creates an **optimize-nodes.sh** script on the server, which can be used to easily optimize the database for the node(s).  If you selected automatic database optimizations, a cronjob is created to run this monthly on a random day at 00:00.

To install Ardor node(s), copy the script to the Debian server run ``bash ./install-ardor.sh``. It is designed to run with a sudo user.

If you don't have a sudo user on the server yet (for example if just created a new Ubuntu Droplet from Digital Ocean), you can use the *create-sudo-user.sh* script to automatically create one.


### create-sudo-user.sh

This script lets you create a sudo user with ease. Call it with ``./create-sudo-user.sh -h`` for parameter description.


### remote-install.sh

This script lets you first create an sudo user and then install the Ardor nodes on an Ubuntu server completely remotely. You just need to configure the configuration sections of this and the *install-ardor.sh* script. It then automatically logs in as the root user on the remote server (ssh pubkey of local machine must be known to the remote server), creates the configured sudo user, copies the *install-ardor.sh* script to the server (logged in as sudo user) and executes it. *The remote-install.sh* script is only tested on Ubuntu and MacOS machines.
The 2 unattended files are to be used by this script.
