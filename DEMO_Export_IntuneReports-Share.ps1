<#
DISCLAIMER:
This script is provided "as is" without warranty of any kind, express or implied. Use this script at your own risk.
The author and contributors are not responsible for any damage or issues potentially caused by the use of this script.
Always test scripts in a non-production environment before deploying them into a production setting.
#>

# API Permissions Required: DeviceManagementManagedDevices.Read.All
# Modules Required: Microsoft.Graph.Authentication

Function Get-IntuneReport() {
    param
        (
            [parameter(Mandatory = $true)]
            $JSON,
            [parameter(Mandatory = $true)]
            $OutputPath

        )
    try {
        $ReportName = ($JSON | ConvertFrom-Json).reportName

        $WebResultApp = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs" -Body $JSON

        # Check if report is ready
        $ReportStatusApp = ""
        $ReportQueryApp = "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$($WebResultApp.id)')"

        do{
            Start-Sleep -Seconds 5
            $ReportStatusApp = Invoke-MgGraphRequest -Method GET -Uri $ReportQueryApp
            if ($?) {
                Write-Host "Report Status: $($ReportStatusApp.status)..."
            }
            else {
                Write-Error "Error"
                break
            }
        } until ($ReportStatusApp.status -eq "completed" -or $ReportStatusApp.status -eq "failed")

    }
        catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex" -f Red
        Write-Host
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Message)"
        Write-Host
        break
    }
    # Extract Report and Rename it
    Remove-Item -Path "$outputpath\$($ReportName)*.csv" -Force
    $ZipPath = "$outputpath\$ReportName.zip"
    Invoke-WebRequest -Uri $ReportStatusApp.url -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $outputpath -Force
    Remove-Item -Path $ZipPath -Force
    Rename-Item -Path "$outputpath\$($ReportStatusApp.Id).csv" -NewName "$($ReportName).csv"
 }

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

$ExportOutput = "C:\TEMP"

#Configuration Profiles
$jsonstring = @"
{"reportName":"ConfigurationPolicyAggregate","filter":"","select":["PolicyName","UnifiedPolicyType","UnifiedPolicyPlatformType","NumberOfCompliantDevices","NumberOfNonCompliantOrErrorDevices","NumberOfConflictDevices"],"format":"csv","snapshotId":"ConfigurationPolicyAggregate_00000000-0000-0000-0000-000000000001","search":""}
"@
 Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Settings Compliance
$jsonstring = @"
{"reportName":"SettingComplianceAggReport","filter":"","select":[],"format":"csv","snapshotId":"SettingComplianceAggReport_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Device Compliance
$jsonstring = @"
{"reportName":"DeviceCompliance","filter":"","select":["DeviceName","UPN","ComplianceState","OS","OSVersion","OwnerType","LastContact"],"format":"csv","snapshotId":"DeviceCompliance_00000000-0000-0000-0000-000000000001","search":""}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Policy Compliance
$jsonstring = @"
{"reportName":"PolicyComplianceAggReport","filter":"","select":[],"format":"csv","snapshotId":"PolicyComplianceAggReport_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Devices Without Compliance
$jsonstring = @"
{"reportName":"DevicesWithoutCompliancePolicy","filter":"","select":["DeviceId","DeviceName","DeviceModel","DeviceType","OSDescription","OSVersion","OwnerType","ManagementAgents","UserId","PrimaryUser","UPN","UserEmail","UserName","AadDeviceId","OS"],"format":"csv","snapshotId":"DevicesWithoutCompliancePolicy_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Devices
$jsonstring = @"
{"reportName":"DevicesWithInventory","filter":"","select":[],"format":"csv","localizationType":"LocalizedValuesAsAdditionalColumn"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Application
$jsonstring = @"
{"reportName":"AppInvRawData","filter":"","select":[],"format":"csv","localizationType":"LocalizedValuesAsAdditionalColumn"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Feature Update Report, replace "PolicyId" with the PolicyId from your feature update policy
$jsonstring = @"
{"reportName":"WindowsUpdatePerPolicyPerDeviceStatus","filter":"(OwnerType eq '1') and (PolicyId eq '5cd33c4d-9d67-438f-adfe-f69eccd29d70')","select":["DeviceName","UPN","DeviceId","AADDeviceId","CurrentDeviceUpdateStatusEventDateTimeUTC","CurrentDeviceUpdateStatus","CurrentDeviceUpdateSubstatus","AggregateState","LatestAlertMessage","LastWUScanTimeUTC","WindowsUpdateVersion"],"format":"csv","snapshotId":"WindowsUpdatePerPolicyPerDeviceStatus_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Readiness Report, with only Corporate Devices and excluded upgraded devices. You will need to use Graph to find the "Group Tag" ID.
$jsonstring = @"
{"reportName":"MEMUpgradeReadinessDevice","filter":"(Ownership eq '1') and (ReadinessStatus eq '0' or ReadinessStatus eq '1' or ReadinessStatus eq '2' or ReadinessStatus eq '3' or ReadinessStatus eq '5') and (TargetOS eq 'NI23H2') and (DeviceScopesTag eq '00004')","select":["DeviceName","DeviceManufacturer","DeviceModel","OSVersion","ReadinessStatus","SystemRequirements","AppIssuesCount","DriverIssuesCount","AppOtherIssuesCount"],"format":"csv","snapshotId":"MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput