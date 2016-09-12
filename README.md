# AzureCalc
Quick and dirty way to automate costing estimation calculations for Azure using Azure Calculator API.

Samples

*Get-AzureVMPrice* -Cores 2 -Ram 30 -Location 'West Europe' -OS Windows
*Get-AzureVMPrice* -Cores 4 -Ram 16 -Location 'West Europe' -OS Windows | sort price


