$ModuleManifestName = 'azurecalc.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"
$current = Get-Location

# trying to import module
Import-Module $ModuleManifestPath -Verbose -Force

# creating a temporary folder under current location
$foldername = "awsregions"
$outPath = join-path -Path $current -ChildPath $foldername
if (! (Test-Path $outPath)) {mkdir $outPath}

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath
        $? | Should Be $true
    }
}

Describe 'Module  Tests' {
    It 'Get-AWSOfferData -Path $outPath -Force -PassThru' {
        $p = Get-AWSOfferData -Path $outPath -Force -PassThru
        (dir $p).count | Should NOT BeNullorEmpty
    }

    It "Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'somenonexistentrgn'"{
        { Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'someregion' } | Should Throw "Please import AWS calc data"
    }

    It "Import-AWSOfferDataFile -Path $outPath" {
        { Import-AWSOfferDataFile -Path $outPath -PassThru } | should NOT Throw
    }

    It "Second import and passthru" {
        $k = Import-AWSOfferDataFile -Path $outPath -PassThru
        $k | should NOT BeNullOrEmpty
        $k | Should BeOfType System.Collections.Hashtable
    }

    It "Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'us-east-1'" {
        { Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'us-east-1' } | Should Not Throw
    }
}


#cleaning up
del $outPath -Force -Recurse