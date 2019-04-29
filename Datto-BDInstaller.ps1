#########################################
#                                     
# Script made by Jono Oh              
# Date: 24 Apr 2019.                  
#                                     
# Intended to be used in Datto RMM    
# for the automatic creation and      
# deployment of the BitDefender AV    
#                                     
# email: jono@ohnyx.co.nz             
#                                     
# Version History:
# 24 Apr 2019 - Initial release
# 27 Apr 2019 - Removed datto api dependency, added contributions and cleaned up some documentation
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
$bitDefenderAPIKey = '562321372dc448ae4f034799fb0907db8e814d3037c6d38b07fb57a2be14cecd'

# Get from GravityZone "My Company" page. Its the one titled "My Company ID". This is the account which has access to all the sub/client accounts.
$bitdefenderCompanyID = '3c14e3ae5d59a35a501e8ab716bc043a'

# Test mode setting - Will only do the actual installation if set to "false". 
$testmode = 'true'

# Verbose output. Useful for debugging if something isn't working properly. Change to "true" to turn on.
$testmodeVerbose = 'false'

##########################
#    No more variables   #
##########################


# Check variables have been changed, explain and exit if not.
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

# Append ":" to the end of the BitDefender API key
$bitDefenderAPIKeyFormatted = $bitDefenderAPIKey + ':'

#find the company name of the device this is running on using the CS_PROFILE_NAME variable

$custName = 'Ohnyx IT Solutions Limited'

Write-Host "`nStarting BitDefender script component."

# Clean up some variables
Remove-Variable custID -ErrorAction SilentlyContinue
Remove-Variable custExists -ErrorAction SilentlyContinue
Remove-Variable custPackage -ErrorAction SilentlyContinue
Remove-Variable packageExists -ErrorAction SilentlyContinue

## Set global variables ##

# change this to the customer name. This is the only modification needed. This should be edited to be an environemnt variable pulled from RMM (i.e. $env:SiteName)
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender custName variable set to: $custName"
}
# Set the API key for BitDefender GravityZone. This may change in the future if the API key is regenerated or permissions on it are changed.
$apikey = $bitDefenderAPIKeyFormatted
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API Key variable set to: $apikey"
}
# Set API endpoint base URI
$api = "https://cloud.gravityzone.bitdefender.com/api/v1.0/jsonrpc"
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API URL variable set to: $api"
}
# Set initial endpoint to work with as the companies one
$endpoint = "$api/companies"
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender API endpoint variable set to: $endpoint"
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
## End global variables ##


## Start Create Company ##

# [Info] Display what company is being created
write-host "Company Name set to" $custName

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
}

write-host "Checking if $custName already exists..."

# Call API to populate custID with company info (if it exists)
$custID = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
If ($testmodeVerbose -ne "false") {
    # Convert results to Json so it all displays
    $custIDTestData = $custID | ConvertTo-Json
    Write-Host "BitDefender retrieved data: $custIDTestData"
}

if ($custID.result)
{ 
    If ($testmodeVerbose -ne "false") {
        Write-Host "Customer ID not empty. Data: $custID.result"
    }
    $custID.result = $custID.result."id"
    write-host "Customer already exists. ID is" $custID.result
    #set variable that customer already exists for use later
    $custExists = "true"
    If ($testmodeVerbose -ne "false") {
        Write-Host "Variable set for customer exists: custExists = $custExists"
    }
}
Else
{
    write-host "Customer does not exist already. Creating company $custName in BitDefender GravityZone..."
    
    # Define variables for making a new company
    $data = @{ 
    "id" = $bitdefenderCompanyID
    "method" = "createCompany"
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


    Try {
        $custID = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
        If ($testmodeVerbose -ne "false") {
            Write-Host "BitDefender API call data returned: "$custID.result
        }
    }
    Catch {
        Write-Error 'error creating company'
    }
    Write-Host $custName "created. ID is" $custID.result
}
Write-Host "BitDefender customer check complete. Moving to package creation."
## End create comapny ##
## Start create package ##

# change API endpoint to packages
$endpoint = "$api/packages" 
If ($testmodeVerbose -ne "false") {
    Write-Host "BitDefender endpoint changed to: $endpoint"
}

# [Info] Notify endpoint change
write-host "API endpoint changed to /packages"

# If the company already exists then check if the package already exists too
If ($custExists -eq "true") {
    
    # [Info] Notify company exists, checking package existance
    write-host "Checking if package already exists for company"

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
        Write-Host "BitDefender API data changed to: $data"
    }
    $body = $data | ConvertTo-Json
    If ($testmodeVerbose -ne "false") {
        Write-Host "BitDefender API data converted to: $body"
    }
    $custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
    If ($testmodeVerbose -ne "false") {
        Write-Host "Data returned from API call: "$custPackage.result
    }

    ################ TO ADD TO MAIN SCRIPT #######################

    # If more than 1 result returned
    If ($custPackage.result.total -gt 1) {
    
        
    }

    ##############################################################


    # If value is returned for customer package it means that one exists. Don't try to make another one.
    If ($custPackage) {
        # convert custPackage to ID to use later
        $custPackage.result = $custPackage.result.items."id"
        $packageExists = "true"
        Write-Host "Package exists. custPackage is" $custPackage.result
    }
    Else {
        Write-Host "A company exists but there are no packages associated. This shouldn't really happen, something else might be wrong. Creating package for company."
        
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

        # If the company has been created successfully then make the associated package
            Try {
                # [Info] Notify package creation
                write-host "Creating installation package for $custName"
                $custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
            }
            Catch {
                Write-Host "Package create failed."
            }
        
        If ($custPackage) {
        # [Info] Notify package created
        write-host "Package created successfully."
        }
        Else {
        Write-Host "Package create failed. Terminating script, something is wrong."
        break
        }
     }
}
Else {

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

    # If the company has been created successfully then make the associated package
    If ($custID.result) {
        Try {
            # [Info] Notify package creation
            write-host "Creating installation package for $custName"
            $custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
        }
        Catch {
            Write-Host "Package create failed."
        }
    }
    Else {
        Write-Host "Company create failed. Terminating script."
        break
    }

    # [Info] Notify package created
    write-host "Package created successfully. "
}
## End create Package ##
## Start get package ID ##

# update data being passed to API endpoint for getting the package install SiteCode
$data = @{
"id" = $bitdefenderCompanyID
"method" = "getInstallationLinks"
"jsonrpc" = "2.0"
"params" = @{
    "packageName" = "Endpoint - $custName"} # End Params
} # End Data

$body = $data | ConvertTo-Json

# If the package was created successfully then get the SiteCode from the installation link
If ($custPackage.result) {
    Try {
        $packageInstallIDRaw = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
    }
    Catch {
        Write-Host "Package not created successfully. terminating script"
        break
    }
}

# Because we only want the SiteCode we need to grab the data between "[" and "]" excluding the brackets from the returned string
$packageInstallIDString = [regex]::match($packageInstallIDRaw.result."installLinkWindows", '\[(.*?)\]').groups[1].value

# [Info] Notify SiteCode
write-host "SiteCode is" $packageInstallIDString

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
Write-Host "Script finished. If not in test mode, setupdownloader.exe should start running on device shortly."
