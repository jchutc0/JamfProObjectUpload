# JamfProObjectUpload
Script to upload XML data from backed up objects to a Jamf Pro server.

Written to upload the data obtained from JamfProObjectBackup  found on Tom Rice's [GitHub Repo](https://github.com/trice81384/JAMF), but could be used with any Jamf Pro valid XML data. 

Tom Rice presented his backup script in his 2023 Jamf Nation User Conference presentation [Back to the Future: Backing up All (most) of the Objects in Jamf Pro](https://youtu.be/h-03QKwHyog?si=eue0BNv33LrCuYIA).

## Usage

    `JamfProObjectUpload.sh [-r] [-s <server name>] [-u <client id>] [-p <client secret>] <file name>...`

Uploads one or more files to a Jamf Pro server through its API. Supports multiple files and wildcards.

Uses API keys which can be set up through the Jamf Pro server (curently under Settings -> System -> API Roles and Clients). The role assigned to the API client ID must have access to to the proper operation or else the Jamf Pro server will send an error. If the server name and/or credentials are not specified, the script will prompt for them.

**Options**

    `-r`
        Run the script in read only mode (no changes to the server)

    `-s <server name>`
        Specify the server name (URL) of the Jamf Pro server

    `-u <client id>`
        Specify the client ID for the Jamf Pro server API

    `-p <client secret>`
        Specify the client secret for the Jamf Pro server API
