#!/bin/bash

# Quick and Dirty script to install Ansible AWX Tower on CentOS

# Author: Raul Bringas (@raulbringasjr)
# Tested on: CentOS 7
# Version: 0.1 - 8/27/2019

# Check to ensure the platform is CentOS
osRelease=`cat /etc/redhat-release | cut -f1 -d" "`

if [[ "$osRelease" == "CentOS" ]]; then
        echo "CentOS detected..."
else
        echo "Silly Rabbit, this is the Wrong OS!"
        echo "Exiting..."
        exit 1
fi

# Disable firewalld
echo -n "Disabling firewall - DANGER WILL ROBINSON..."
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# Set selinux to disabled permanently
echo -n "Disabling SELINUX - DANGER WILL ROBINSON..."
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# Install dependencies
echo -n "Installing Dependencies..."
sudo yum install epel-release -y
(($? != 0)) && { printf '%s\n' "Failed to install epel repository, check internet connection!"; exit 1; }

sudo yum install docker python-pip git npm -y
(($? != 0)) && { printf '%s\n' "Failed to install AWX dependencies, check internet connection!"; exit 1; }

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
sudo pip install docker-compose
(($? != 0)) && { printf '%s\n' "Failed to install docker-compose, check internet connection!"; exit 1; }

# Verify to ensure URL is still valid, update as necessary
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
(($? != 0)) && { printf '%s\n' "Failed to install docker-compose, check URL and internet connection!"; exit 1; }
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Edit inventory variables
echo -n "Creating Data Directories for Postgres and awxcompose..."
sudo mkdir -p /var/lib/pgdocker
sudo mkdir -p /var/lib/awxcompose

# Make sure to leave the \ to escape / in the chosen directory path
echo -n "Editing AWX Installer Inventory with custom data directory..."
sudo sed -i 's/postgres_data_dir=\/tmp\/pgdocker/postgres_data_dir=\/var\/lib\/pgdocker/g' /opt/awx/installer/inventory
sudo sed -i 's/docker_compose_dir=\/tmp\/awxcompose/docker_compose_dir=\/var\/lib\/awxcompose/g' /opt/awx/installer/inventory

# Start and enable docker
echo -n "Starting and Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Change passwords and awx secret to a good strong password
# Optional: Change default admin username to something else
# sudo sed -i 's/admin_user=admin/admin_user=CHANGEME' /opt/awx/installer/inventory
echo -n "Changing Default AWX Tower password..."
sudo sed -i 's/admin_password=password/admin_password=Ch4ng3M3N0w' /opt/awx/installer/inventory

# Run the installer
echo -n "Starting AWX installation..."
cd /opt/awx/installer
sudo ansible-playbook -i inventory install.yml
