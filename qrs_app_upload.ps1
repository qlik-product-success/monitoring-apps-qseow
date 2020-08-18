<#
CMT requested pwe 1 time 

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

    Folder to store the output files (response from API)

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

    .PARAMETER ClientPfxFile

    Path where the Client cert is, it is necessary include the file name

    .EXAMPLE
    Using exported Certificates(Remote Server):
    All Apps
    C:\PS> .\qrs_app_upload.ps1 -UserName Administrator -UserDomain Domain -FQDN qlikserver1.domain.local -AppQVFPath "C:\ProgramData\Qlik\Sense\Repository\DefaultApps\*" -ClientPfxFile "C:\CustomerFirst\qlikserver1.domain.local\client.pfx" 
    Single App
    C:\PS> .\qrs_app_upload.ps1 -UserName Administrator -UserDomain Domain -FQDN qlikserver1.domain.local -AppQVFPath "C:\ProgramData\Qlik\Sense\Repository\DefaultApps\Sessions Monitor.qvf" -ClientPfxFile "C:\CustomerFirst\qlikserver1.domain.local\client.pfx" -AppName "Sessions Monitor Test API Upload"

    Running with the Service Account on Central Node
    All Apps
    C:\PS> .\qrs_app_upload.ps1 -AppQVFPath "C:\ProgramData\Qlik\Sense\Repository\DefaultApps\*" 
    Single App
    C:\PS> .\qrs_app_upload.ps1 "C:\ProgramData\Qlik\Sense\Repository\DefaultApps\Sessions Monitor.qvf" -Trace $True -AppName "Sessions Monitor Test API Upload"

    .NOTES

    This script is provided "AS IS", without any warranty, under the MIT License.

    Version:        1.0
    Author:         Nadia Gomez
    Creation Date:  8/18/2020
    Purpose/Change: Initial script to upload QVF's to QMC

    Copyright (c) 2020

#>

# Default to node where script is executed and the executing user

[CmdletBinding()]
param (

    [Parameter()]

    [string] $UserName = $env:USERNAME,

    [Parameter()]

    [string] $UserDomain = $env:USERDOMAIN,

    [Parameter()]

    [string] $FQDN = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname,

    [Parameter()]

    [string] $CertIssuer = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname,

    [Parameter()]

    [string] $Output = $PSScriptRoot,

    [Parameter(Mandatory = $true)]

    [string] $AppQVFPath,

    [Parameter()]

    [string] $AppName,

    [Parameter()]

    [Bool] $KeepData,

    [Parameter()]

    [Bool] $ExcludeConnections,

    [Parameter()]

    [bool] $Trace,

    [Parameter()]

    [string] $ClientPfxFile

)

function PathExists
(
    [parameter(Mandatory = $true)]
    [String]$Path
        
) {
   
    if ([IO.Directory]::Exists($Path)) { 
        return $true 
    } 
    else { 
        return $false 
    } 
}

function FileExists
(
    [parameter(Mandatory = $true)]
    [String]$FilePath
        
) {
   

    if ([System.IO.File]::Exists($FilePath)) { 
        return $true
    } 
    else { 
        return $false
    } 
}


function PathHasFiles
(
    [parameter(Mandatory = $true)]
    [String]$Path,
    [parameter(Mandatory = $true)]
    [String]$FileExtension
        
) {
   
    if (Test-Path $Path\*$FileExtension -PathType Leaf ) {
        Return $true
    }
    else {
        Return $false
    }

}

function TypeOfUpload() {


    if ($AppQVFPath -match '\*') 
    { return 1 }
    else {
        if ($AppQVFPath -like '*.qvf')
        { return 0 }
        else { 
            if ((!$AppQVFPath -or $AppQVFPath -notlike '*.qvf')) {
                Write-Host "Invalid AppQVFPath, it is required a valid path or QVF path E.g. c:Folder\* or c:\Folder\AppName.qvf" -ForegroundColor Red
                write-host $AppQVFPath
                Exit
            }
        }

    }

}

function Trace () {
    if ($Trace) {
        Write-Host "*****************PARAMETERS***************************"
        Write-Host "FileAppDetails: $FileAppDetails"
        Write-Host "Body: $HttpBody"
        Write-Host "PSS root : $PSScriptRoot"
        Write-Host "AppName: $AppName"
        Write-Host "User: $UserDomain\$UserName"
        Write-Host "URL: $URI"
        Write-Host "Cert Path :$ClientPfxFile"
        Write-Host "AppName: $AppName"
        Write-Host "ApplicationPath: $ApplicationPath"
        Write-host "KeepData: $KeepData"
        write-host "XrfKey : $XrfKey"
        write-host "ExcludeConnections: $ExcludeConnections"              
        write-host "FileAppDetails: $FileAppDetails"
        write-host "Headers $HttpHeaders"

    }
}

function UploadApp {

    #Variables initialization 

    if (!$KeepData) { $KeepData = $true }
    if (!$ExcludeConnections) { $ExcludeConnections = $false }
    if (!$Trace) { $Trace = $false }

   # Qlik Sense client certificate to be used for connection authentication

    if (!$ClientPfxFile) {
        $cert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Issuer -like "*$($CertIssuer)*" }

        if (($cert | measure-object).count -ne 1) {
            Write-Host "Failed. Could not find one unique certificate." -ForegroundColor Red
            Exit
        }
    }
    else {
        $cert = Get-PfxCertificate -FilePath $ClientPfxFile
    }


    # 16 character Xrefkey to use for QRS API call
    # Reference XrfKey; https://help.qlik.com/en-US/sense-developer/Subsystems/RepositoryServiceAPI/Content/Sense_RepositoryServiceAPI/RepositoryServiceAPI-Connect-API-Using-Xrfkey-Headers.htm

    [String]$XrfKey = "12345678qwertyui"

    # HTTP headers to be used in REST API call
    $HttpHeaders = @{ }
    $HttpHeaders.Add("X-Qlik-Xrfkey", "$XrfKey")
    $HttpHeaders.Add("X-Qlik-User", "UserDirectory=$UserDomain;UserId=$UserName")

    $ScriptTime = Get-Date -Format "ddMMyyyyHHmmss"
    $FileAppDetails = "$Output\QRS_App_$AppName`_$ScriptTime.json"

    # Invoke REST API call - /qrs/app/upload , Uploads an app into QMC
    try {


        [int]$TypeOfUpload = TypeOfUpload $AppQVFPath


        if ($TypeOfUpload -eq 1) {
            [Boolean]$PathExists = PathExists $AppQVFPath.Replace('*','')
            [Boolean]$PathHasFiles = PathHasFiles $AppQVFPath.Replace('*','') ".qvf"

            if ( $PathExists -and $PathHasFiles) {
                Get-ChildItem $AppQVFPath -Filter *.qvf |
                Foreach-Object {

                    $AppName = $_.BaseName

                    $ApplicationPath = $_.FullName.Replace('\', '/')

                    QRS_UploadAPP $HttpHeaders $XrfKey $KeepData $ExcludeConnections $AppName $ApplicationPath $cert $FileAppDetails

                   # Write-Host $_.BaseName path: $_.FullName
                    $AppName = '';

                    Trace
                }
            }
            else
            { Write-Host "Invalid Path or no QVF files were found." -ForegroundColor Red }

        }
        else {
            
            if ($TypeOfUpload -eq 0) {

                if (!$AppName) { $AppName = (Get-Item $AppQVFPath).BaseName }
                $ApplicationPath = (Get-Item "$($AppQVFPath)" ).FullName
                $ApplicationPath = $ApplicationPath.Replace('\', '/')

                QRS_UploadAPP $HttpHeaders $XrfKey $KeepData $ExcludeConnections $AppName $ApplicationPath $cert $FileAppDetails
            }
        }
    } 
    catch [System.Net.WebException] { 
        Write-Verbose "An exception was caught: $($_.Exception.Message)" 
        $_.Exception.Response 

       
        $resp = $_.Exception.Response

        if ($null -eq $resp) {
            Write-host $_.Exception
        }
        else {
            $reqstream = $resp.GetResponseStream()
            $sr = New-Object System.IO.StreamReader $reqstream
            $body = $sr.ReadToEnd()

            Write-host -Text "Response Headers:" 
            Write-Output "         Status: $([int]$resp.StatusCode) - $($resp.StatusCode)"
            foreach ($HeaderKey in $resp.Headers) {
                $caption = $HeaderKey.PadLeft(15, " ")
                Write-host "$caption`: $($resp.Headers[$HeaderKey])";
            }
            Write-host "$body" -ForegroundColor red

            $resp.StatusCode                
        }                    

    } 
    catch {            
        Write-host  $_.Exception
    }
}

function QRS_UploadAPP
(

    [parameter(Mandatory = $true)]
    $HttpHeaders,
    [parameter(Mandatory = $true)]
    [String]$Xrfkey,
    [parameter(Mandatory = $true)]
    [Bool]$KeepData,
    [parameter(Mandatory = $true)]
    [Bool]$ExcludeConnections,
    [parameter(Mandatory = $true)]
    [String]$AppName,
    [parameter(Mandatory = $true)]
    [String]$ApplicationPath,
    [parameter(Mandatory = $true)]
    $cert,
    [parameter(Mandatory = $true)]
    [String]$FileAppDetails
) {


    $URI = "https://$($FQDN):4242/qrs/app/upload?xrfkey=$($Xrfkey)&keepdata=$($KeepData)&excludeconnections=$($ExcludeConnections)&name=$($AppName)"

    Invoke-RestMethod   -Uri $URI `
        -Method POST `
        -Headers $HttpHeaders `
        -ContentType "application/vnd.qlik.sense.app" `
        -InFile $ApplicationPath `
        -Certificate $cert | ConvertTo-Json -Depth 10 | Out-File -FilePath "$FileAppDetails"

        Write-Host "Application $AppName was upoaded"


}

UploadApp