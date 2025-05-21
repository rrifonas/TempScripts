<#
DISCLAIMER:
This script is provided "as is" without warranty of any kind, express or implied. Use this script at your own risk.
The author and contributors are not responsible for any damage or issues potentially caused by the use of this script.
Always test scripts in a non-production environment before deploying them into a production setting.
#>
# API Permissions Required: Group.Read.All, GroupMember.ReadWrite.All, User.Read.All, Device.Read.All
# Modules Required: Microsoft.Graph.Authentication, Microsoft.Graph.Groups
# Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Groups
# Import-Module Microsoft.Graph.Authentication
# Import Module Microsoft.Graph.Groups

<# 
#############################################################################
#Authentication with App Registration

# Populate with the App Registration details and Tenant ID
$ClientId          = ""
$ClientSecret      = "" 
$tenantid          = "" 


# Create ClientSecretCredential
$secret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secret

# Authenticate to the Microsoft Graph
Connect-MgGraph  -TenantId $tenantid -ClientSecretCredential $ClientSecretCredential
#############################################################################
#>

# Connect to Microsoft Graph
Connect-MgGraph

# Declare Groups
$InitialGroupName = "_TEST_MIXED" # Initial Group
$deviceOutGroup = "_TEST_DEVICE"  # New Device Group
$userOutGroup = "_TEST_USER"      # New User Group

# Clean user and devices variables
$users= @()
$devices=@()

# Get Group Id
$GroupId = Get-MgGroup -Filter "displayname eq '$InitialGroupName'"

# Read all members of the initial group
$GroupMembers = Get-MgGroupMember -All -GroupId $GroupId.Id

# Check if members are user or device; add them to a variable
foreach ($member in $Groupmembers) {
    $type = $member.AdditionalProperties.'@odata.type'
    $name = $member.AdditionalProperties.displayName

    switch ($type) {
        "#microsoft.graph.user"   { $users+=$member.Id; Write-Output "$name is a User" }
        "#microsoft.graph.device" { $devices+=$member.Id;Write-Output "$name is a Device" }
        default                   { Write-Output "$name is of unknown type ($type)" }
    }
}

# Populate User Group
Write-Output "Populate User Group"
$UserGroupId = Get-MgGroup -Filter "displayname eq '$userOutGroup'"
foreach ($user in $users) {
    New-MgGroupMember -GroupId $UserGroupId.Id -DirectoryObjectId $user #-ErrorAction SilentlyContinue
}

Write-Output "Populate Device Group"
$UserGroupId = Get-MgGroup -Filter "displayname eq '$deviceOutGroup'"
foreach ($device in $devices) {
    New-MgGroupMember -GroupId $UserGroupId.Id -DirectoryObjectId $device #-ErrorAction SilentlyContinue
}

Disconnect-MgGraph