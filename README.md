# DattoRMM-BitDefenderInstaller
BitDefender Installer script for Datto RMM

This is an automated script built for use in Datto RMM that deploys BitDefender on an endpoint by using a component. 

If you're not using the compiled .cpt file then you will need to put in the package variables:
rmmvBitDefenderAPIKey - The BitDefender API Key
rmmvBitDefenderCompanyID - The BitDefender CompanyID
TestMode (Selection) - any value apart from "false" will set it to test mode.
VerboseOutput - on/off selection

The script connects to the BitDefender GraviyZone API and does the following:

Gets the company name of the site that the target endpoint is registered in in Datto RMM
Checks to see if that company already exists in BitDefender
If it doesn't exist already, it will create it
Once the company exists, it will check if a package is already associated with the company
If a package already exists, it grabs the install info for it. If it doesn't, it will create a package and associate it. It accounts for when there are multiple packages by selecting the first one
Once it has the package ID it downloads the installer to the endpoint and runs it. 
