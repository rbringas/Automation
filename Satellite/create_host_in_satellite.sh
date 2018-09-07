#!/bin/bash
# Bash script to create a new host in Satellite using Hammer CLI
# Author: Raul Bringas
# https://github.com/rbringas


###################################################
# Function Declarations						      #
###################################################
function GetOSID () {

	# Convert the $OS_id string value passed into the script to a numerical value for corresponding Satellite OS_id
	# Determine the $Medium_id string value based on the $OS_id passed into the script and set a numerical value for corresponding Satellite Medium_id

	# Change the OS_id, and Medium_id values below to match your Satellite environment
	# Use hammer-cli to obtain the corresponding numerical values...
	case $OS_id in


		"RHEL Server 6.8")
		Message="RHEL Server 6.8 Selected"
		OS_id= # The actual os id equivalent in satellite
		Medium_id= # The actual medium id equivalent in satellite
		;;

		"RHEL Server 6.9")
		Message="RHEL Server 6.9 Selected"
		OS_id= # The actual os id equivalent in satellite
		Medium_id= # The actual medium id equivalent in satellite
		;;

		"RHEL Server 6.10")
		Message="RHEL Server 6.10 Selected"
		OS_id= # The actual os id equivalent in satellite
		Medium_id= # The actual medium id equivalent in satellite
		;;

		"RedHat 7.3")
		Message="RedHat 7.3 Selected"
		OS_id= # The actual os id equivalent in satellite
		Medium_id= # The actual medium id equivalent in satellite
		;;

		"RedHat 7.4")
		Message="RedHat 7.4 Selected"
		OS_id= # The actual os id equivalent in satellite
		Medium_id= # The actual medium id equivalent in satellite
		;;

		"RedHat 7.5")
		Message="RedHat 7.5 Selected"
		OS_id= # The actual os id equivalent in satellite
		Medium_id= # The actual medium id equivalent in satellite
		;;

		*) # Default case
		Message="Non-recognized OS detected, exiting..."
		echo $Message
		exit 1
		;;
	esac

	echo $Message
	echo OS id: $OS_id
	echo Medium id: $Medium_id

}

function GetPTableID () {

	# Convert the $PTable_id string value passed into the script to a numerical value for corresponding Satellite PTable_id
	# Change the PTable_id values below to match your Satellite environment
	# Use hammer-cli to obtain the corresponding numerical values...

	case $PTable_id in

		"Kickstart Default")
		Message="Kickstart Default Selected"
		PTable_id= # The actual ptable id equivalent in satellite
		;;

		"Kickstart - EL6")
		Message="Kickstart - EL6 Selected"
		PTable_id= # The actual ptable id equivalent in satellite
		;;

		"Kickstart - EL7")
		Message="Kickstart - EL7 Selected"
		PTable_id= # The actual ptable id equivalent in satellite
		;;

		*) # Default case
		Message="Non-recognized partition table detected, exiting..."
		echo $Message
		exit 1
		;;
	esac

	echo $Message
	echo PTable_id id: $PTable_id


}


function GetSubnetID () {

	# Change the Subnet_id values below to match your Satellite environment
	# Use hammer-cli to obtain the corresponding numerical values...

	case $Subnet_id in

		"10.10.10.x")
		Message="10.10.10.x Selected"
		Subnet_id= # The actual subnet id equivalent in satellite
		;;

		"10.20.20.x")
		Message="10.20.20.x Selected"
		Subnet_id= # The actual subnet id equivalent in satellite
		;;

		*) # Default case
		Message="Non-recognized Subnet detected, exiting..."
		echo $Message
		exit 1
		;;
	esac

	echo $Message
	echo Subnet is $Subnet_id

}

# Convert the uppercase ServerName to lowercase and append domain.
# Change the domain suffix to match your environment...
# $1 is the Server Name passed to this script
ServerFQDN="$(echo "$1" | awk '{print tolower($0)".EXAMPLE.COM"}')"

# Variable Definitions
# These variables are being passed in by an ansible playbook in this order
# Alternatively the script can be called and these variables can be passed in the same order...
MAC=$2
Subnet_id=${3}
IPAddress=$4
Eth_Name=$5
Host_Parameters=$6
Activation_Keys=$7
OS_id=$8
PTable_id=$9
Medium_id=${10}

# Call SubnetID function to determine numerical Satellite ID from Subnet Text selection
GetSubnetID $Subnet_id

# Call GetOSID function to determine numerical Satellite ID for OS and Medium from OS Text selection
GetOSID $OS_id

# Call GetPTableID function to determine numerical Satellite ID from Partition table Text selection
GetPTableID $PTable_id

# This is where your Satellite server will store the boot iso
# ISO can be saved on a SMB, NFS mount point, etc.
# ISOPath="/Path/To/ISO/${ServerFQDN}.iso"
# Edit this to match your environment...
ISOPath="/Path/To/ISO/${ServerFQDN}.iso"

# Hammer CLI to create a host in Satellite
# The IDs below are converted using the functions above to determine the id number
# These values are being collected using Ansible surveys and playbooks for automation

# These values must be set for your specific Satellite environment...
# Use hammer-cli to obtain these values and fill out the variables below
Domain_id =
Arch_id =
Org_id =
Location_id =
CV_id =
CS_id =
LC_id =
Env_id =
Puppet_CA_id =
Puppet_id =
Owner_id =

echo "Creating Hammer host: ${ServerFQDN}"
hammer host create \
 --name "${ServerFQDN}" \
 --interface=primary=true,mac=${MAC},ip=${IPAddress},subnet_id=${Subnet_id},identifier=${Eth_Name},provision=true \
 --domain-id "${Domain_id}" \
 --architecture-id "${Arch_id}" \
 --operatingsystem-id "${OS_id}" \
 --partition-table-id "${PTable_id}" \
 --medium-id "${Medium_id}" \
 --build yes \
 --organization-id "${Org_id}" \
 --location-id "${Location_id}" \
 --content-view-id "${CV_id}" \
 --content-source-id "${CS_id}" \
 --lifecycle-environment-id "${LC_id}" \
 --environment-id "${Env_id}" \
 --puppet-ca-proxy-id "${Puppet_CA_id}" \
 --puppet-proxy-id "${Puppet_id}" \
 --parameters "${Host_Parameters}" \
 --root-pass change-me \
 --owner-id "${Owner_id}" \
 --owner-type Usergroup

# The activation keys are set using Ansible variables defined below
# You can also set these variables locally in this script
# Activation_Keys =

echo "Setting Host Parameter Activation Keys for: ${ServerFQDN}"
hammer host set-parameter \
--name kt_activation_keys \
--value "${Activation_Keys}" \
--host "${ServerFQDN}"

# After the host is created in Satellite, the boot iso is created and stored in your defined ISO Path
# The ISO can be attached to the server and it can be booted up and provisioned
echo "Creating hammer bootdisk for ${ServerFQDN} in ${ISOPath}"
hammer bootdisk host --host "${ServerFQDN}" --file "${ISOPath}"
