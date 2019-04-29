#Requires -Version 3.0
#########################################
#                                     
# Script made by Jono Oh              
# Date: 24 Apr 2019.                  
#                                     
# Intended to be used in Datto RMM for the automatic creation and deployment of the BitDefender AV    
#                              
# email: jono@ohnyx.co.nz             
#                                     
# Version History:
# 24 Apr 2019 - Initial release
# 27 Apr 2019 - Removed datto api dependency, added contributions and cleaned up some documentation
# 30 Apr 2019 - Re-worked logic to account for packages already existing. Removed dependancy on specific package name. Added additional error checking 
#
# Full BitDefender API documentation at https://download.bitdefender.com/business/API/Bitdefender_GravityZone_Cloud_APIGuide_forPartners_enUS.pdf
#
# Assumptions - You have partner level access to BitDefender GravityZone and API generated. Script running on Windows computer
#
# Contributions:
# Michael_McCool - Pointed out that the site name is an available environemnt variable. Enabled me to remove the entire Datto API portion of the script.
#
#


##########################
# Set required variables #
##########################

# You don't need to change these anymore. Just update the variables in the component.

# Put values between the single quotes

# Get from GravityZone "My Account" page. It needs at least Companies and Packages API. 
$bitDefenderAPIKey = $env:rmmvBitDefenderAPIKey

# Get from GravityZone "My Company" page. Its the one titled "My Company ID". This is the account which has access to all the sub/client accounts.
$bitdefenderCompanyID = $env:rmmvBitDefenderCompanyID

# Test mode setting - Will only do the actual installation if set to "false". 
$testmode = $env:TestMode

# Verbose output. Useful for debugging if something isn't working properly. Change to "true" to turn on.
$testmodeVerbose = $env:VerboseOutput

#find the Site name of the device this is running on using the CS_PROFILE_NAME variable
$custName = $env:CS_PROFILE_NAME

##########################
#    No more variables   #
##########################


# Run some initial environment checks
If ($bitDefenderAPIKey -eq 'xxxxxxxxxx') {
    Write-Host "You have not updated the BitDefender API Key. It will not work without this. Existing script."
    exit
}
Elseif ($bitdefenderCompanyID -eq 'xxxxxxxxxx') {
    Write-Host "You have not updated the BitDefender Company ID. It will not work without this. Existing script."
    exit
}
Else {
    Write-Host "Variables changed from default. Continuing."
}

# Check Powershell Version is at least version 3.0
if ($PSVersionTable.PSVersion.Major -le 3) {
    Write-Host "This script uses Invoke-RestMethod which was introduced in Powershell 3.0.`nPowershell needs to be at least version 3 to run this script. Update powershell before running this."
    exit
}

# Clean up custExists variable - For re-testing script in ISE
$custExists = ''

# Append ":" to the end of the BitDefender API key
$bitDefenderAPIKeyFormatted = $bitDefenderAPIKey + ':'

Write-Host "`nStarting BitDefender script component."

## Set global variables ##

# Set the API key for BitDefender GravityZone.
$apikey = $bitDefenderAPIKeyFormatted
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API Key variable set to: $apikey"
}

# Set API endpoint base URI
$api = "https://cloud.gravityzone.bitdefender.com/api/v1.0/jsonrpc"
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API URL variable set to: $api"
}

# Convert the API key to Basic - needed for auth
$bytes = [System.Text.Encoding]::ASCII.GetBytes($apikey)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"

# Set the header to use the Basic Auth converted above
$headers = @{ Authorization = $basicAuthValue }
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender headers variable set to: $headers"
}

# [Info] Display what company is being created
write-host "Company Name set to" $custName

## End global variables ##


## Start Create Company ##


# Set endpoint to work with as the companies one
$endpoint = "$api/companies"
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API endpoint variable set to: $endpoint"
}

# Check if the company already exists
$data = @{ 
"id" = $bitdefenderCompanyID
"method" = "findCompaniesByName"
"jsonrpc" = "2.0"
"params" = @{
    "nameFilter" = "$custName"}
} 

# Convert the body data to json format for use in API
$body = $data | ConvertTo-Json
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API data set to: $body"
    Write-Host "Endpoint: $endpoint `nHeaders: "$headers.Values
}

Write-Host "Checking if $custName already exists"

# Call API to populate custID with company info (if it exists)
$custID = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'

If ($testmodeVerbose -ne "false") {
    # Convert results to Json so it all displays
    $custIDTestData = $custID | ConvertTo-Json
    Write-Host "BitDefender retrieved data: $custIDTestData"
}

# If a result was returned (can only ever be one, BD has its own check for names being unique)
if ($custID.result.count -eq 1)
{ 
    If ($testmodeVerbose -ne "false") {
        Write-Host "Customer ID not empty. Data: "$custID.result
    }
    $custID.result = $custID.result."id"
    write-host "Customer already exists. ID is" $custID.result
    #set variable that customer already exists for use later
    $custExists = "true"
    If ($testmodeVerbose -ne "false") {
        Write-Host "Variable set for customer exists: custExists = $custExists"
    }
}
Else {
    Write-Host "Customer does not exist already. Creating company $custName in BitDefender GravityZone..."
    
    # Define variables for making a new company
    $data = @{ 
    "id" = $bitdefenderCompanyID
    "method" = 'createCompany'
    "jsonrpc" = "2.0"
    "params" = @{
        "type" = 1
        "name" = "$custName"}
    } 
    If ($testmodeVerbose -ne "false") {
        Write-Host "BitDefender API data changed to: $data"
    }
    # Convert the body data to json format
    $body = $data | ConvertTo-Json
    If ($testmodeVerbose -ne "false") {
        Write-Host "BitDefender API data updated. New values: $body"
    }
    
    $custID = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
    If ($custID.result) {
        Write-Host "Create company success"
    }
    Else {
        Write-Host "Create company failed. Exiting script, something went wrong."
        exit
    }

    If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API call data returned: "$custID.result
    }

    Write-Host $custName "created. ID is" $custID.result
}

Write-Host "BitDefender customer check complete. Moving to package creation."
## End create comapny ##
## Start process package ##

# Change API endpoint to packages
$endpoint = "$api/packages" 
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender endpoint changed to: $endpoint"
}

# If the company already exists, check if a package already exists.
If ($custExists -eq "true") {
    
    # [Info] Notify company exists, checking package existance
    write-host "Checking if package already exists for $custName"

    # Set data for the check
    $data = @{
    "id" = $bitdefenderCompanyID
    "method" = "getPackagesList"
    "jsonrpc" = "2.0"
    "params" = @{
        "companyId" = $custID.result
        } #End Params
    } #End Data
    If ($testmodeVerbose -ne "false") {
        Write-Host "BitDefender API data changed to: "$data.Values
    }

    $body = $data | ConvertTo-Json
    If ($testmodeVerbose -ne "false") {
        Write-Host "BitDefender API data converted to: $body"
    }

    $custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
    If ($testmodeVerbose -ne "false") {
        Write-Host "Data returned from API call: "$custPackage.result
    }

    # If value is returned for customer package it means that at least one exists. Don't try to make another one, get details of current one.
    If ($custPackage.result.items) {

        # If there is more than 1 package, just get the ID of the first package
        If ($custPackage.result.total -gt 1) {
            Write-Host "Multiple packages already exists. ID's are:" $custPackage.result.items."id"
            $custPackageID = $custPackage.result.items."id" | Select-Object -first 1
            Write-Host "Grabbed first result as package to use"
        }
        Elseif ($custPackage.result.total -eq 1) {
            Write-Host "Package already exists. ID is: " $custPackage.result.items."id"
            $custPackageID = $custPackage.result.items."id"
        }

        Write-Host "Using package ID: $custPackageID"

        Write-Host "Getting name of package"

        $data = @{
        "id" = $bitdefenderCompanyID
        "method" = "getPackageDetails"
        "jsonrpc" = "2.0"
        "params" = @{
            "packageId" = $custPackageID} # End Params
        } # End Data

        $body = $data | ConvertTo-Json

        $packageName = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'

        Write-Host "Retrieved package name: "$packageName.result.packageName

        $custPackageName = $packageName.result.packageName

    }
    
    Else { # No existing package found. Make a new one. 
        Write-Host "A company exists but there are no packages associated with it. Creating package for company."
        Write-Host "Using default package name: Endpoint - $custName"
        $custPackageName = "Endpoint - $custName"
        
        # update data being passed to API endpoint for making the package
        $data = @{ 
        "id" = $bitdefenderCompanyID
        "method" = "createPackage"
        "jsonrpc" = "2.0"
        "params" = @{
            "packageName" = $custPackageName
            "companyId" = $custID.result
            "description" = "Endpoint for $custName - automatically generated"
            "language" = "en_US"
            "modules" = @{
                "atc" = 1
                "firewall" = 1
                "contentControl" = 1
                "deviceControl" = 1
                "powerUser" = 1
                }
            "scanMode" = @{
                "type" = 1
                }
            "settings" = @{
                "scanBeforeInstall" = 0
                }
            "roles" = @{
                "relay" = 0
                "exchange" = 0
                }
            "deploymentOptions" = @{
                "type" = 1
                }
            } # End Params
        } # End Data

        $body = $data | ConvertTo-Json
        
        # [Info] Notify package creation
        $custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
        
        # Check package created successfully
        If ($custPackage.result.success -eq "True") {
            Write-Host "Package created successfully."
            Write-Host "ID is: " $custPackage.result.records
        }
        Else {
            Write-Host "Package create failed. Terminating script, something went wrong."
            break
        }
     }
}
Else {
    Write-Host "Company didn't exist before so no package could have been associated with it. Making new package with default values."
    Write-Host "Using default package name: Endpoint - $custName"
    $custPackageName = "Endpoint - $custName"

    # update data being passed to API endpoint for making the package
    $data = @{ 
    "id" = $bitdefenderCompanyID 
    "method" = "createPackage"
    "jsonrpc" = "2.0"
    "params" = @{
        "packageName" = "Endpoint - $custName"
        "companyId" = $custID.result
        "description" = "Endpoint for $custName - automatically generated"
        "language" = "en_US"
        "modules" = @{
            "atc" = 1
            "firewall" = 1
            "contentControl" = 1
            "deviceControl" = 1
            "powerUser" = 1
            }
        "scanMode" = @{
            "type" = 1
            }
        "settings" = @{
            "scanBeforeInstall" = 0
            }
        "roles" = @{
            "relay" = 0
            "exchange" = 0
            }
        "deploymentOptions" = @{
            "type" = 1
            }
        } # End Params
    } # End Data

    $body = $data | ConvertTo-Json

    # [Info] Notify package creation
    write-host "Creating installation package for $custName"
    $custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
        
    # Check package created successfully
    If ($custPackage.result.success -eq "True") {
        Write-Host "Package created successfully."
        Write-Host "ID is: " $custPackage.result.records
    }
    Else {
        Write-Host "Package create failed. Terminating script, something went wrong."
        break
    }
}
## End process Package ##
## Start get package ID ##

Write-Host "Getting site code for installation"

# update data being passed to API endpoint for getting the package install SiteCode
$data = @{
"id" = $bitdefenderCompanyID
"method" = "getInstallationLinks"
"jsonrpc" = "2.0"
"params" = @{
    "packageName" = $custPackageName} # End Params
} # End Data

$body = $data | ConvertTo-Json

$packageInstallIDRaw = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
If ($testmodeVerbose -ne "false") {
    Write-Host "Data returned for package ID: "$packageInstallIDRaw.result
}

# Check that something was pulled. Otherwise notify and exit
If ($packageInstallIDRaw.result.Count -lt 1) {
    Write-Host "No data pulled for install links. Exiting."
    exit
}

# Because we only want the SiteCode we need to grab the data between "[" and "]" excluding the brackets from the returned string
$packageInstallIDString = [regex]::match($packageInstallIDRaw.result."installLinkWindows", '\[(.*?)\]').groups[1].value

# [Info] Notify SiteCode
write-host "Site code is" $packageInstallIDString

## End get package ID ##
## Start install on endpoint ##

If ($testmode -eq "false") {
    
    # [Info] Notify installation starting
    write-host "Initialising BitDefender install on endpoint"
    
    Invoke-WebRequest -Uri "http://download.bitdefender.com/business/misc/kb1695/eps_installer_signed.zip" -OutFile "$env:temp/eps_installer_signed.zip"
    
    # [Info] Notify download client complete
    write-host "eps installer downloaded"

    Expand-Archive "$env:temp/eps_installer_signed.zip" -DestinationPath $env:temp/eps_installer_signed/ -Force
    
    # [Info] Notify archive expanded
    write-host "Archive expanded"

    cd $env:temp/eps_installer_signed
    
    # [Info] Notify change directory
    write-host "directory changed to eps_installer_signed"

    # [Info] Notify starting client install
    write-host "executing installer with SiteCode"

    & ./eps_installer_signed.msi /qn GZ_PACKAGE_ID=$packageInstallIDString REBOOT_IF_NEEDED=1

    Write-Host "The installation will proceed in the background to download the files and then install. The process name(s) are: installation file, setupdownloader.exe, MSIA64A4.tmp. if you need to check."
}
Else {
    Write-Host "Script in test mode. Skipping client install."
    break
}

## End install on endpoint ##
Write-Host "Script finished. If not in test mode, setupdownloader.exe should start running on device shortly. Full download size is around 700mb, time to deploy on device will vary on internet speed."
