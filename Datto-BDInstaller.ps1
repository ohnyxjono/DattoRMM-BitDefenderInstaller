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
# 30 Apr 2019 - Re-worked logic to account for packages already existing. Removed dependancy on specific package name. Added additional error checking. Added overrides for company name and package ID 
# 3 May 2019 - Added tiered overrides, skips, made install sequence more efficient, better error checking and feedback 
# 5 May 2019 - Combined testmode and verbose logging. Added check if BD is already installed. Reordered some variables in the component. Added exit code 1 for fails. Updated some descriptions. Made some output more readable. Changed customer name override logic to not need the initial value to be false.
# 25 May 2019 - Removed duplicate PS version check (IF check) - superceeded by #requires on line 1. Reworded some of the script completion messages. Made it clear that the API key display is test mode data. Added TODO's in notes.
#
# Full BitDefender API documentation at https://download.bitdefender.com/business/API/Bitdefender_GravityZone_Cloud_APIGuide_forPartners_enUS.pdf
#
# Assumptions - You have partner level access to BitDefender GravityZone and API generated. Script running on Windows computer
#
# Contributions:
# Michael_McCool - Pointed out that the site name is an available environemnt variable. Enabled me to remove the entire Datto API portion of the script.
#
# Notes
#
# For site level: Site, Settings, Variables.
# To change the default company name, make a variable called "SiteNameOverride" and give it the name of the BitDefender company to use.
# To change the default package thats used, make a variable called "PackageIDOverride" and give it the ID of the BitDefender package installer
#
# TODO
# clean up testmode & testmodeverbose variables
# convert all "true"/"false" checks to booleans and then use $true & $false instead
# a number of parts would probably be more efficient as functions
# array declarations repeat a lot. I'm pretty sure the way they are declared could be made more efficient



##########################
# Set required variables #
##########################

# Don't change these. Just update the variables in the component.

$bitDefenderAPIKey = $env:rmmvBitDefenderAPIKey

$bitdefenderCompanyID = $env:rmmvBitDefenderCompanyID

$testmode = $env:TestMode

$testmodeVerbose = $testmode

If ($testmodeVerbose -ne "false") {
    Write-Host "Verbose logging on"
}

# Company name: If no customer name override is set at component or site level then use the Site name of the endpoint in Datto RMM using the CS_PROFILE_NAME variable
If ($env:rmmvCustNameOverride.Length -lt 1) {
    
    If ($testmodeVerbose -ne "false") {
        Write-Host "Component level customer name override not set"
    }
    #If no override is set, check if Site level name override is set and use it, if not then use the Site name.
    If ($env:SiteNameOverride.Length -gt 0) {
        $custName = $env:SiteNameOverride
        Write-Host "Site level SiteName override is set. Using $custName as customer name"
    }
    Else {
        $custName = $env:CS_PROFILE_NAME
        If ($testmodeVerbose -ne "false") {
            Write-Host "Site level customer name override not set"
        }
        Write-Host "Using Datto RMM Site name as BitDefender Company name: $custName"
    }
}
Else {
    $custname = $env:rmmvCustNameOverride
    Write-Host "Customer name override set. Customer name is:" $custName
}

# Package overrides: Use rmmvPackageOverride if it exists (running component instnace), then try PackageIDOverride (site variable), then fall back to normal script (find/create).
If ($env:rmmvPackageOverride -like "*=") {
    $packageInstallIDString = $env:rmmvPackageOverride
    $skipToInstall = 'true'
    Write-Host "Component level package override set. `nSkipping to install.`nPackage ID set to $packageInstallIDString "
}
Else {
    # If the override isn't set, then check the PackageIDOverride field. If thats set then use it. If not then 
    
    If ($testmodeVerbose -ne "false") {
        Write-Host "`nComponent level package override not set."
    }
    If ($env:PackageIDOverride -like "*=") {
        $packageInstallIDString = $env:PackageIDOverride
        Write-Host "Site level Package ID Override set and passed initial validation. `nSkipping to install. `nPackage ID set to: "$packageInstallIDString 
        $skipToInstall = 'true'
    }
    Else {
        If ($testmodeVerbose -ne "false") {
            Write-Host "No package overrides set"
        }
    }
}

##########################
#    No more variables   #
##########################

# Check if Bitdefender Endpoint Security is already installed
$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -like "Bitdefender Endpoint Security*" }) -ne $null
If (-Not $installed) {
    Write-Host "Bitdefender is not already installed."
}
Else {
    Write-Host "Bitdefender is already installed."
    exit 1
}

# Display environment variables for verbose output
If ($testmodeVerbose -ne "false") {
    Write-Host "`nEnvironment variables set:" 
    get-childitem env:\
}

# If skip to install is true, skip to the installer
If ($skipToInstall -ne 'true') {

	# Run some initial environment checks
	If ($bitDefenderAPIKey -eq 'xxxxxxxxxx') {
		Write-Host "You have not updated the BitDefender API Key. It will not work without this. Existing script."
		exit 1
	}
	Elseif ($bitdefenderCompanyID -eq 'xxxxxxxxxx') {
		Write-Host "You have not updated the BitDefender Company ID. It will not work without this. Existing script."
		exit 1
	}
	Else {
		Write-Host "`nChecking variables have been changed from the defaults complete."
	}

	# Append ":" to the end of the BitDefender API key
	$bitDefenderAPIKeyFormatted = $bitDefenderAPIKey + ':'

	## Set global variables ##

	# Set the API key for BitDefender GravityZone.
	$apikey = $bitDefenderAPIKeyFormatted
	If ($testmodeVerbose -ne "false") {
		Write-Host "[TEST MODE DATA] BitDefender API Key variable set to: $apikey"
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

	# If a result was returned then the company exists. Get the ID. (Can only ever be one company with a given name, BD has its own check for names being unique)
	if ($custID.result.count -eq 1) { 
		If ($testmodeVerbose -ne "false") {
			Write-Host "Customer ID not empty. Data: "$custID.result
		}

		$custID.result = $custID.result."id"

		write-host "Customer already exists. ID is" $custID.result

		#set variable that customer already exists for use later
		$custExists = "true"
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
        
        # If script set to not make any changes to BitDefender, exit
        If ($env:rmmvAllowBDChange -eq 'false') {
            Write-Host "Script was about to create a company in BitDefender GravityZone because an existing company for this endpoint does not exist already and a package override was not set. 
            `nOption has been set to not make any changes. Script will now exit as it will fail with no company name set."		
            exit 1
        }

		$custID = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
		If ($custID.result) {
			Write-Host "$custName created successfully. ID is:" $custID.result
		}
		Else {
			Write-Host "Create company failed. Exiting script"
			exit 1
		}

		If ($testmodeVerbose -ne "false") {
		Write-Host "BitDefender API call data returned: "$custID.result
		}
	}

	Write-Host "BitDefender company check complete. Moving to package creation."

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
			}
		}
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

		# If value is returned for customer package it means that at least one exists already. Don't try to make another one, get details of a current one.
		If ($custPackage.result.items) {

			# If there is more than 1 package, just get the ID of the first package
			If ($custPackage.result.total -gt 1) {
				Write-Host "Multiple packages already exist. ID's are:" $custPackage.result.items."id"
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
				"packageId" = $custPackageID}
			}

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

            # If no changes to BD are to be made, exit
            If ($env:rmmvAllowBDChange -eq 'false') {
                Write-Host "Script was about to create a package for $custName as an existing one was not found. `nOption set to not make changes. Exiting script."
                exit 1
            }
			
			$custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
			
			# Check package created successfully
			If ($custPackage.result.success -eq "True") {
				Write-Host "Package created successfully."
				Write-Host "ID is: " $custPackage.result.records
			}
			Else {
				Write-Host "Package create failed. Terminating script."
                $custPackage = $custPackage | ConvertTo-Json
                Write-Host "Available data (if any) from API call:" $custPackage
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
        
        # If no changes to BD are to be made, exit
        If ($env:rmmvAllowBDChange -eq 'false') {
            Write-Host "Script was about to create a package for $custName as an existing one was not found. `nOption set to not make changes. Exiting script."
            exit 1
        }

		$custPackage = Invoke-RestMethod -uri $endpoint -Headers $headers -Body $body -Method POST -ContentType 'application/json'
			
		# Check package created successfully
		If ($custPackage.result.success -eq "True") {
			Write-Host "Package created successfully."
			Write-Host "ID is: " $custPackage.result.records
		}
		Else {
			Write-Host "Package create failed. Terminating script"
            $custPackage = $custPackage | ConvertTo-Json
            Write-Host "Available data pulled from API (If any): " $custPackage
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
		Write-Host "No data pulled for install links. Likely the package was not created successfully. Terminating script."
		exit 1
	}

	# Because we only want the SiteCode we need to grab the data between "[" and "]" excluding the brackets from the returned string
	$packageInstallIDString = [regex]::match($packageInstallIDRaw.result."installLinkWindows", '\[(.*?)\]').groups[1].value

	# [Info] Notify SiteCode
	write-host "Site code is" $packageInstallIDString

	## End get package ID ##
}# End if for skipToInstaller
## Start install on endpoint ##
    
# [Info] Notify installation starting
write-host "`nInitialising BitDefender install on endpoint"

# Check if the MSI package exists
If (Test-Path ".\eps_installer_signed.msi" -PathType Leaf){
    write-host "MSI Installer exists in directory"
}
Else {
    Write-Host "MSI Installer doesn't exist. Can't install, exiting"
    exit 1
}

# Make log file to inspect if something goes wrong
$DateStamp = get-date -Format ddMMyyyyTHHmmss
$logFile = "$env:temp\BDInstallLog$DateStamp.log"

# [Info] Notify logfile location
Write-Host "`nLog file for install location: $env:temp\BDInstallLog$DateStamp.log"

# [Info] Notify package ID being used
Write-Host "`nPackage ID is: " $packageInstallIDString

If ($testmode -eq "false") {
    & ./eps_installer_signed.msi /qn /L*v $logFile GZ_PACKAGE_ID=$packageInstallIDString REBOOT_IF_NEEDED=1

    Write-Host "Installation started. 'setupdownloader.exe' should be running on the endpoint which indicates it is running the install successfully.`nThe full download size is arounf 700mb, internet speed will impact how long the installation will take"
}
Else {
    Write-Host "Script in test mode. Skipping client install."
    break
}

## End install on endpoint ##
Write-Host "Script finished."