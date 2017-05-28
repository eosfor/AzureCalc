# AzureCalc
Quick and dirty way to automate costing estimation calculations for Azure using Azure Calculator API.

[![Build status](https://ci.appveyor.com/api/projects/status/2rerdsc4j1g2dl94?svg=true)](https://ci.appveyor.com/project/eosfor/azurecalc)

# Install
```powershell code
Install-Module -Name AzureCalc
```
# Samples
Simple set of examplese
```powershell code
Get-AzureCalcData
Get-AzureCalcPrice -Size A4v2 -Region asia-pacific-southeast, canada-east, us-east, us-west | ft -AutoSize
Get-AzureCalcPrice -Type Windows -Size a4v2 -Region asia-pacific-east,  europe-west, us-east | ft -AutoSize
```
More complex variants
```powershell code
Get-AzureCalcData
Get-AzureCalcPrice -Size F8 -Region australia-east -Tier standard -Type windows | ft -AutoSize
Get-AzureCalcPrice -Size F2 -Region australia-east -Tier standard -Type windows | ft -AutoSize
Get-AzureCalcPrice -CPU (8..16) -RAM (20..40) -Region australia-east -Tier standard -Type windows | sort  australia-east | ft -AutoSize
```

I've added some AWS related data. To use it:

download AWS calc  data (for EC2 only) by issuing
```powershell code
Get-AWSOfferData -Path c:\temp\awsdata -Force -PassThru
```

next step is to import that data into global variable. you can also use -PassThru parameter to save the reference to a variable
```powershell code
Import-AWSOfferDataFile -Path c:\temp\awsdata
```
and now you can search
```powershell code
Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'us-east-1'
```
