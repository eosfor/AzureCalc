Import-Module "..\AzureCalc" -verbose

Describe "AzureCalc tests"{
    Context "extract data from azure"{
        it "Extract data"{
            Get-AzureCalcData | Should Not Throw
        }
    }
}