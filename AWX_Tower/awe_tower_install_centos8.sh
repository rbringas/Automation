#!/bin/bash

# Quick and Dirty script to install Ansible AWX Tower on CentOS

# Author: Raul Bringas (@raulbringasjr)
# Tested on: CentOS 8
# Version: 0.1 - 12/20/2019

# Check to ensure the platform is CentOS
osRelease=`cat /etc/redhat-release | cut -f1 -d" "`

if [[ "$osRelease" == "CentOS" ]]; then
        echo "CentOS detected..."
else
        echo "Silly Rabbit, this is the Wrong OS!"
        echo "Exiting..."
        exit 1
fi

# Random passwords generated during installation
## Check /opt/awx/installer/inventory file after install to find random passwords ##
AWX_ADMIN=`openssl rand -base64 30`
AWX_PG_ADMIN=`openssl rand -base64 30`
AWX_PG=`openssl rand -base64 10`
AWX_SECRET=`openssl rand -base64 30`

# AWX Inventory file used for installation
AWX_INVENTORY=/opt/awx/installer/inventory

# Set selinux to disabled (FOR DEV)
# Will determine what context or booleans needed for PROD
echo -n "Disabling SELINUX - DANGER WILL ROBINSON..."
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# Install dependencies
echo -n "Installing Dependencies..."
sudo dnf install epel-release -y
(($? != 0)) && { printf '%s\n' "Failed to install epel repository, check internet connection!"; exit 1; }

sudo dnf install git gcc gcc-c++ nodejs gettext device-mapper-persistent-data lvm2 bzip2 python3-pip -y
(($? != 0)) && { printf '%s\n' "Failed to install AWX dependencies, check internet connection!"; exit 1; }

# Adding for CentOS8 as it no longer supports direct install of Docker
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
(($? != 0)) && { printf '%s\n' "Failed to add Docker CE repo, check internet connection!"; exit 1; }

# Install Docker CE
sudo dnf install docker-ce-3:18.09.1-3.el7 -y
(($? != 0)) && { printf '%s\n' "Failed to install Docker CE , check internet connection!"; exit 1; }

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable --now docker.service
(($? != 0)) && { printf '%s\n' "Failed to start Docker CE, check logs!"; exit 1; }

# Ansible is failing to install the first time around due to not finding a valid repo...
# This hack works for now until a better alternative is found...
sudo yum clean all
sudo yum install ansible -y
(($? != 0)) && { printf '%s\n' "Failed to install ansible, check internet connection!"; exit 1; }

# Clone AWX Tower Repository
echo -n "Cloning AWX Tower Repository..."
git clone https://github.com/ansible/awx.git
# Check if the repository clone was successful... Otherwise exit the script
(($? != 0)) && { printf '%s\n' "Failed to clone AWX, check internet connection!"; exit 1; }

# Install Docker-compose
echo -n "Installing Docker Compose..."
sudo pip3 install docker-compose
(($? != 0)) && { printf '%s\n' "Failed to install docker-compose, check internet connection!"; exit 1; }

# Edit inventory variables
echo -n "Creating Data Directories for Postgres and awxcompose..."
sudo mkdir -p /var/lib/pgdocker
sudo mkdir -p /var/lib/awxcompose

# Make sure to leave the \ to escape / in the chosen directory path
echo -n "Editing AWX Installer Inventory with custom data directory..."
sudo sed -i 's/postgres_data_dir="~\/.awx\/pgdocker"/postgres_data_dir=\/var\/lib\/pgdocker/g' ${AWX_INVENTORY}
sudo sed -i 's/docker_compose_dir="~\/.awx\/awxcompose"/docker_compose_dir=\/var\/lib\/awxcompose/g' ${AWX_INVENTORY}

# Start and enable docker
echo -n "Starting and Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Change default passwords and awx secret to a good strong password
echo -n "Changing Default AWX Tower password..."
sudo sed -i "s/admin_password=password/admin_password=${AWX_ADMIN}/g" ${AWX_INVENTORY}

echo -n "Changing Default AWX PG password..."
sudo sed -i "s/pg_password=awxpass/pg_password=${AWX_PG}/g" ${AWX_INVENTORY}

echo -n "Changing Default AWX PG Admin password..."
sudo sed -i "s/# pg_admin_password=postgrespass/pg_admin_password=${AWX_PG_ADMIN}/g" ${AWX_INVENTORY}

echo -n "Changing Default AWX Secret key..."
sudo sed -i "s/secret_key=awxsecret/secret_key=${AWX_SECRET}/g" ${AWX_INVENTORY}

# Changes the second occurence to python3 to use the correct interpreter
# anisble_python_interpreter="/usr/bin/env python3"
echo -n "Changing Default python interpreter to python3..."
sed -i ':a;N;$!ba;s/python/python3/2' ${AWX_INVENTORY}

# Run the installer
echo -n "Starting AWX installation..."
cd /opt/awx/installer
sudo ansible-playbook -i inventory install.yml

# Adjusting permissions on inventory file
echo -n "Adjusting Permissions on Inventory file..."
chmod 0400 ${AWX_INVENTORY}

# Setup Firewall rules for AWX Tower
firewall-cmd --zone=public --add-port=80/tcp
firewall-cmd --zone=public --add-port=443/tcp

# Need to add this for the NFT upgrade from IPTables on CentOS8
# This enables docker to communicate externally
firewall-cmd --zone=public --add-masquerade --permanent
firewall-cmd --reload

# Setup SELinux rules/context for AWX Tower
# Must use audit2allow to troubleshoot and determine what is needed...
