$ModuleManifestName = 'azurecalc.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"

Import-Module $ModuleManifestPath -Verbose -Force

$outPath = 'E:\temp\awsoffers1.csv'
if (Test-Path $outPath) {del $outPath}

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath
        $? | Should Be $true
    }
}

Describe 'Module  Tests' {
    It 'Passes Get-AWSOfferData to a new file' {
        $res = Get-AWSOfferData -Path $outPath -PassThru
        $res | Should not BeNullOrEmpty
    }
    It 'Passes Get-AWSOfferData to an existing file' {
        { Get-AWSOfferData -Path $outPath -PassThru } | Should Throw
    }
    It 'Passes Get-AWSOfferData to an existing file forcibly override' {
        { Get-AWSOfferData -Path $outPath -Force } | Should NOT Throw
    }

    It "Passes Import-AWSOfferDataFile" {
    }
}
