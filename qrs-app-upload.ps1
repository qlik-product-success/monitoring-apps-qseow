<#

    .DESCRIPTION

    This script calls QRS APIs to a Qlik Sense central node to upload Applications

    Reference
    https://help.qlik.com/en-US/sense-developer/April2020/Subsystems/RepositoryServiceAPI/Content/Sense_RepositoryServiceAPI/RepositoryServiceAPI-App-Upload-App.htm
    https://help.qlik.com/en-US/sense-developer/April2020/APIs/RepositoryServiceAPI/index.html?page=318
    

    .PARAMETER  FQDN

    Hostname to Qlik Sense central node, towards which QRS API call is execute to.  

    .PARAMETER  UserName

    User to be impersonated during QRS API call. Note, API call result reflects the user's authorized access right.

    .PARAMETER  UserDomain

    Domain that user belongs to in Qlik Sense user list.

    .PARAMETER  CertIssuer

    Hostname used to sign the Qlik Sense CA certificate

    .PARAMETER  Output

    Folder to store JSON exports in

    .PARAMETER AppName,

    Aplication name that will be used when uploading the app

    .PARAMETER AppQVFPath,

    Path where the QVF resides 

    .PARAMETER KeepData,

    If set to false and the imported .qvf file contains app data, the data will be silently discarded. The default value is true.

    .PARAMETER ExcludeConnections

    If set to true and the imported .qvf file contains any data connections, they will not be imported to the system. The default value is false.

    .PARAMETER Trace

    Prints variables to verify their values, default false

    .EXAMPLE

    C:\PS> .\qrs-app-upload.ps1 -AppQVFPath "C:/DemoApps/Helpdesk Management.qvf" 

    .EXAMPLE

    C:\PS> .\qrs-app-upload.ps1 -UserName Administrator -UserDomain Domain -FQDN qlikserver3.domain.local -AppQVFPath "C:/DemoApps/Helpdesk Management.qvf" 

    .EXAMPLE

    C:\PS> .\qrs-app-upload.ps1 -UserName Administrator -UserDomain Domain -FQDN qlikserver3.domain.local -AppQVFPath "C:/DemoApps/Helpdesk Management.qvf" -KeepData false

    .NOTES

    This script is provided "AS IS", without any warranty, under the MIT License.

    Copyright (c) 2020

#>

# Paramters for REST API call

# Default to node where script is executed and the executing user

param (

    [Parameter()]

    [string] $UserName   = $env:USERNAME,

    [Parameter()]

    [string] $UserDomain = $env:USERDOMAIN,

    [Parameter()]

    [string] $FQDN       = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname,

    [Parameter()]

    [string] $CertIssuer = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname,

    [Parameter()]

    [string] $Output     = $PSScriptRoot,

    [Parameter()]

    [string] $AppName,

    [Parameter(Mandatory=$true)]

    [string] $AppQVFPath,

    [Parameter()]

    [string] $KeepData,

    [Parameter()]

    [string] $ExcludeConnections,

    [Parameter()]

    [string] $Trace

)

#Variables initialization 

if (!$KeepData) {$KeepData= "true"}
if (!$ExcludeConnections) {$ExcludeConnections= "false"}
if (!$Trace) {$Trace= "false"}

# Qlik Sense client certificate to be used for connection authentication

# Note, certificate lookup must return only one certificate.

$ClientCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Subject -like '*QlikClient*'}

# Timestamp for output files

$ScriptTime = Get-Date -Format "ddMMyyyyHHmmss"

# Only continue if one unique client cert was found

if (($ClientCert | measure-object).count -ne 1) {

    Write-Host "Failed. Could not find one unique certificate." -ForegroundColor Red

    Exit

}

# 16 character Xrefkey to use for QRS API call

# Reference XrfKey; https://help.qlik.com/en-US/sense-developer/Subsystems/RepositoryServiceAPI/Content/Sense_RepositoryServiceAPI/RepositoryServiceAPI-Connect-API-Using-Xrfkey-Headers.htm

$XrfKey = "12345678qwertyui"

# HTTP headers to be used in REST API call

$HttpHeaders = @{}

$HttpHeaders.Add("X-Qlik-Xrfkey","$XrfKey")

$HttpHeaders.Add("X-Qlik-User", "UserDirectory=$UserDomain;UserId=$UserName")

$HttpBody = @{}


if (!$AppName) {$AppName =$AppQVFPath.Replace(".qvf", "").Replace(" ","") }
$AppName=$AppName.Split("/")[-1].Replace("""","")

$FileAppDetails      = "$Output\QRS_App_$AppName`_$ScriptTime.json"

$FileAppDetails      = "$Output\QRS_App$AppName`_$ScriptTime.json"

$URI = "https://$($FQDN):4242/qrs/app/upload?xrfkey=$($xrfkey)&keepdata=$($KeepData)&excludeconnections=$($ExcludeConnections)&name=$($AppName)"

if ($Trace= "true")
{
Write-Host "FileAppDetails: $FileAppDetails"
Write-Host "Body: $HttpBody"
Write-Host "PSS root : $PSScriptRoot"
Write-Host "AppName: $AppName"
Write-Host "User: $UserDomain\$UserName"
Write-Host "URL: $URI"
Write-Host "App Path :$AppQVFPath"
}

# Invoke REST API call - /qrs/app/upload , Uploads an app into QMC
try
{

Invoke-RestMethod -Uri $URI -Method POST -Headers $HttpHeaders -ContentType "application/vnd.qlik.sense.app" -InFile $AppQVFPath -Certificate $ClientCert | ConvertTo-Json -Depth 10 | Out-File -FilePath "$FileAppDetails"

} 
catch [System.Net.WebException] 
{ 
    Write-Verbose "An exception was caught: $($_.Exception.Message)" 
    $_.Exception.Response 


    }