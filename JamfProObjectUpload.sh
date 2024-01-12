#!/bin/bash

#### #### #### #### #### #### #### #### #### #### 
# default values
#### #### #### #### #### #### #### #### #### #### 
declare scriptname=$(basename "$0")
declare client_id
declare client_secret
declare servername
declare token
declare read_only_mode

#### #### #### #### #### #### #### #### #### #### 
# functions
#### #### #### #### #### #### #### #### #### #### 
function ScriptLogging {
## Function to provide logging of the script's actions either to the console or the log file specified.
## Developed by Rich Trouton https://github.com/rtrouton
    local LogStamp=$(date +%Y-%m-%d\ %H:%M:%S)    
    echo "$LogStamp [$scriptname]:" " $1"
}

#### #### #### #### #### #### #### #### #### #### 
function exit_with_error {
	local error_message="$1"
	ScriptLogging "[ERROR] ${error_message}"
	echo "${error_message}" 1>&2
	exit 1
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
		echo "Detail: ${webdata}"
		exit_with_error "Unable to connect to server. See detail above."
    fi
	if ! token=$(printf "%s" "${webdata}" | /usr/bin/plutil -extract "access_token" raw -o - -); then
		ScriptLogging "Token data error. Exiting."
		echo "Server response: ${webdata}"
		exit_with_error "Unable to extract token data"
	fi
	if ! checkToken; then 
		ScriptLogging "Token validation error. Exiting."
		echo "Server response: ${webdata}"
		exit_with_error "Unable to get token data"
	fi
	ScriptLogging "Bearer Token: $token"
}

#### #### #### #### #### #### #### #### #### #### 
function uploadFile {
	local request_method="$1"
	local server_path="$2"
	local filename="$3"
	ScriptLogging "Uploading file $filename to Jamf Pro server"
	ScriptLogging "Checking for file"
	if ! [ -r "$filename" ]; then
		exit_with_error "Error! Cannot read file $filename"
	fi
	ScriptLogging "TODO: Decide how to handle existing"
	ScriptLogging "For now, all are treated as new"
	ScriptLogging "If we change, request_method should be PUT and jamf_id should be the policy"
	if ! local server_response=$(/usr/bin/curl -i \
		--request "${request_method}" \
		--header "Authorization: Bearer ${token}" \
		--header "Content-Type: application/xml" \
		--data-ascii @"$filename" \
		"${servername}${server_path}"); then
		echo "Detail: ${webdata}"
		exit_with_error "Unable to connect to server"
	fi
	ScriptLogging "Checking the response status"
	local response_status=$(echo "$server_response" | head -n 1 | cut -d$' ' -f2)
	ScriptLogging "Status: $response_status"
	if [ "$response_status" -lt 200 ] || [ "$response_status" -gt 299 ]; then
		echo "$server_response"	
		exit_with_error "Error! The Jamf server returned an error! See above for details."
	fi 
}

#### #### #### #### #### #### #### #### #### #### 
function uploadNewFile {
	local filename="$1"
	local jamf_type="$2"
	local url_path="$3"
	ScriptLogging "Uploading $jamf_type $filename to Jamf Pro server"
	uploadFile "POST" "/JSSResource${url_path}" "${filename}"
	ScriptLogging "Success: $jamf_type $filename upload"
}

#### #### #### #### #### #### #### #### #### #### 
function processFile {
	local filename="$1"
	ScriptLogging "Processing file $filename"
	ScriptLogging "Checking file extension"
	if [[ $(basename "$filename" .xml) == $(basename "$filename") ]]; then
		echo ""
		echo "WARNING!!!! ${filename} does not have the .xml extension. Attempting to continue anyway."
		echo "This program requires XML files to upload to the server."
		echo ""
	fi
	if [ "$read_only_mode" = true ]; then continue; fi
	ScriptLogging "Checking for valid XML"
	if ! xml=$(/usr/bin/xmllint "$filename" 2> /dev/null); then
		exit_with_error "Error! Invalid XML file data."
	fi	
	ScriptLogging "Attempting to determine Jamf data type"
	# find the first line in the XML (without the <xml version... line)
	if ! data_type=$(grep -v '<\?xml version' -m1 <<< "${xml}"); then
		exit_with_error "Unknown error in reading XML data for ${filename}"
	fi
	ScriptLogging "Checking $data_type for valid data type"
	case "${data_type}" in
		"<account>") 
			uploadNewFile "${filename}" "user account" "/accounts/userid/0";;
		"<advanced_computer_search>")
			uploadNewFile "${filename}" "advanced computer search" "/advancedcomputersearches/id/0";;
		"<category>")
			uploadNewFile "${filename}" "category" "/categories/id/0";;
		"<computer_extension_attribute>")
			uploadNewFile "${filename}" "computer extension attribute" "/computerextensionattributes/id/0";;
		"<computer_group>")
			uploadNewFile "${filename}" "account goup" "/computergroups/id/0";;
		"<department>")
			uploadNewFile "${filename}" "department" "/departments/id/0";;
		"<group>")
			uploadNewFile "${filename}" "account goup" "/accounts/groupid/0";;
		"<os_x_configuration_profile>")
			uploadNewFile "${filename}" "configuration profile" "/osxconfigurationprofiles/id/0";;
		"<policy>")
			uploadNewFile "${filename}" "policy" "/policies/id/0";;
		"<restricted_software>")
			uploadNewFile "${filename}" "restricted software" "/restrictedsoftware/id/0";;
		"<script>")
			uploadNewFile "${filename}" "script" "/scripts/id/0";;
			
		*) exit_with_error "Unsupported data type $data_type";;
	esac
}

#### #### #### #### #### #### #### #### #### #### 
function usage {
	local error_message="$1"
	if [ -n "${error_message}" ]; then
		echo "${error_message}" 1>&2
		echo ""
	fi
	echo "Usage"
	echo "    ${scriptname} [-r] [-s <server name>] [-u <client id>] [-p <client secret>] <file name>..."
	echo ""
	echo "Uploads one or more files to a Jamf Pro server through its API. Supports multiple files and wildcards."
	echo ""
	echo "Uses API keys which can be set up through the Jamf Pro server (curently under Settings -> System -> API Roles and Clients). The role assigned to the API client ID must have access to to the proper operation or else the Jamf Pro server will send an error. If the server name and/or credentials are not specified, the script will prompt for them."
	echo ""
	echo "Options"
	echo "    -r"
	echo "        Run the script in read only mode (no changes to the server)"
	echo "    -s <server name>"
	echo "        Specify the server name (URL) of the Jamf Pro server"
	echo "    -u <client id>"
	echo "        Specify the client ID for the Jamf Pro server API"
	echo "    -p <client secret>"
	echo "        Specify the client secret for the Jamf Pro server API"
	
	exit 1
}

#### #### #### #### #### #### #### #### #### #### 
# main
#### #### #### #### #### #### #### #### #### #### 
ScriptLogging "Starting..."
echo "JamfProObjectUpload.sh"

## Handle Command Line Options
while getopts ":hp:rs:u:" flag
do
	case "${flag}" in
		h) usage;;
		p) client_secret="${OPTARG}";;
		r) read_only_mode=true;;
		s) servername="${OPTARG}";;
		u) client_id="${OPTARG}";;
		:) usage "-${OPTARG} requires an argument.";;
		?) usage;;
	esac
done
## Remove the options from the parameter list
echo "$@"
shift $((OPTIND-1))

if [ "$#" -eq 0 ]; then
	usage "Specify one or more files to process."
fi

ScriptLogging "Checking for server name"
while [ -z "${servername}" ]; do
	read -r -p "Please enter the URL to the Jamf Pro server (starting with https): " servername
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

requestToken

for file in "$@"; do
	processFile "$file"
done

ScriptLogging "Exiting..."
exit 0