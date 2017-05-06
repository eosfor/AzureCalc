# AzureCalc
Quick and dirty way to automate costing estimation calculations for Azure using Azure Calculator API.

Samples
```powershell code
Get-AzureCalcData
Get-AzureCalcPrice -Size A4v2 -Region asia-pacific-southeast, canada-east, us-east, us-west | ft -AutoSize
Get-AzureCalcPrice -Type Windows -Size a4v2 -Region asia-pacific-east,  europe-west, us-east | ft -AutoSize
```
