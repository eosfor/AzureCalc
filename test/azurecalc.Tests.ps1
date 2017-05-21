$ModuleManifestName = 'azurecalc.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"

Import-Module $ModuleManifestPath -Verbose -Force

$outPath = 'E:\temp\awsregions'
if (! (Test-Path $outPath)) {mkdir $outPath}

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath
        $? | Should Be $true
    }
}

Describe 'Module  Tests' {
    It 'Passes Get-AWSOfferData to a new folder (does not exist)' {
        { Get-AWSOfferData -Path $outPath } | Should Throw
    }
    It 'Passes Get-AWSOfferData to an existing folder with files' {
        $p = Get-AWSOfferData -Path $outPath -Force -PassThru
        (dir $p).count | Should NOT BeNullorEmpty
    }

    It "Passes Import-AWSOfferDataFile" {
        { Import-AWSOfferDataFile -Path $outPath -PassThru } | should NOT Throw
    }
}
