#!/bin/bash

#### #### #### #### #### #### #### #### #### #### 
# default values
#### #### #### #### #### #### #### #### #### #### 
scriptname=$(basename "$0")
declare client_id
declare client_secret
declare servername
declare token
declare read_only_mode
declare -a policy_list

#### #### #### #### #### #### #### #### #### #### 
# functions
#### #### #### #### #### #### #### #### #### #### 
function usage {
	echo "Usage"
	echo "\t${scriptname} [-r] [-u client_id] [-s servername] [[-p policy_file]...]"
	echo ""
	echo "Options"
	echo "\t-p policy_file" 
	echo "\t\tAdd an XML file to the list of policy files to upload. Multiple -p options can be processed."
	echo "\t-s servername"
	echo "\t\tSpecify the server name (URL) of the Jamf Pro server"
	echo "\t-u client_id"
	echo "\t\tSpecify the client_id for the Jamf Pro server API"
	echo "\t-r"
	echo "\t\tRun the script in read only mode"
	exit 1
}

#### #### #### #### #### #### #### #### #### #### 
function ScriptLogging {
## Function to provide logging of the script's actions either to the console or the log file specified.
## Developed by Rich Trouton https://github.com/rtrouton
    local LogStamp=$(date +%Y-%m-%d\ %H:%M:%S)    
    echo "$LogStamp [$scriptname]:" " $1"
}

#### #### #### #### #### #### #### #### #### #### 
function parseTokenData {
	local tokenData
	tokenData="$1"
	echo "Token data: $tokenData"	
	bearerToken=$(printf "%s" "${tokenData}" | /usr/bin/plutil -extract "access_token" raw -o - -)
	echo "Bearer Token: $bearerToken"

}
#### #### #### #### #### #### #### #### #### #### 
function checkToken {
	ScriptLogging "Checking token..."
	if [ -n "${token}" ]; then
		ScriptLogging "Valid token"
		return 0
	fi
	ScriptLogging "Invalid token"
	return 1
}
#### #### #### #### #### #### #### #### #### #### 
function requestToken {
	local webdata
	if checkToken; then return; fi
	ScriptLogging "Getting new token"
	if ! webdata=$(curl --request POST "${servername}/api/oauth/token" \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "grant_type=client_credentials" \
        --data-urlencode "client_id=${client_id}" \
        --data-urlencode "client_secret=${client_secret}"); then
		ScriptLogging "Connection error. Exiting."
		echo "Unable to connect to server"
		echo "Detail: ${webdata}"
		exit 1
    fi
	if ! token=$(printf "%s" "${webdata}" | /usr/bin/plutil -extract "access_token" raw -o - -); then
		ScriptLogging "Token data error. Exiting."
		echo "Unable to extract token data"
		echo "Server response: ${webdata}"
		exit 1
	fi
	if ! checkToken; then 
		ScriptLogging "Token validation error. Exiting."
		echo "Unable to get token data"
		echo "Server response: ${webdata}"
		exit 1
	fi
	ScriptLogging "Bearer Token: $token"
}

#### #### #### #### #### #### #### #### #### #### 
function uploadPolicy {
	ScriptLogging "Uploading policy $1 to Jamf Pro server"
}

#### #### #### #### #### #### #### #### #### #### 
function processPolicies {
	ScriptLogging "Processing policies"
	for policy_file in "${policy_list[@]}"; do
		ScriptLogging "Policy: $policy_file"
		ScriptLogging "Checking file extension"
		if [[ $(basename "$policy_file" .xml) == $(basename "$policy_file") ]]; then
			echo ""
			echo "WARNING!!!! ${policy_file} does not have the .xml extension. Attempting to continue anyway."
			echo "This program requires XML files to upload to the server."
			echo ""
		fi
		if [ "$read_only_mode" = true ]; then continue; fi
		uploadPolicy $policy_file
	done
}

#### #### #### #### #### #### #### #### #### #### 
# main
#### #### #### #### #### #### #### #### #### #### 
ScriptLogging "Starting..."
echo "JamfProObjectUpload.sh"

## Handle Command Line Options
while getopts "s:u:p:rh" flag
do
	case "${flag}" in
		h) usage;;
		p) policy_list+=("${OPTARG}");;
		r) read_only_mode=true;;
		s) servername="${OPTARG}";;
		u) client_id="${OPTARG}";;
		*) usage;;
	esac
done

ScriptLogging "Checking for server name"
while [ -z "${servername}" ]; do
	read -r -p "Please enter the URL to the Jamf Pro server (starting with http): " servername
done

ScriptLogging "Checking for client_id"
while [ -z "${client_id}" ]; do
	read -r -p "Please enter a Jamf API client ID: " client_id
done

ScriptLogging "Checking for client_secret"
while [ -z "${client_secret}" ]; do
	read -r -s -p "Please enter a Jamf API client secret: " client_secret
	echo ""
done

# requestToken

processPolicies


ScriptLogging "Exiting..."