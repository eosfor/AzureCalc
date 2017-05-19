function Get-AWSOfferData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,
        [switch]$Force,
        [switch]$PassTrough
    )
    process {
        if (Test-Path $Path -AND (! $Force.IsPresent)) {
            $awsOffersFileURI = 'https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/index.csv'
            $tempFile = New-TemporaryFile
            Write-Verbose "new temp file is $tempFile"
        
            Write-Verbose 'downloading offer file'
            Invoke-WebRequest -Uri $awsOffersFileURI -OutFile $tempFile
        
            Write-Verbose 'reading temp file'
            $sourceFile = [System.IO.File]::ReadAllLines($tempFile)
        
            Write-Verbose 'writing destination file'
            [System.IO.File]::WriteAllLines($Path, ($sourceFile[5..($sourceFile.count)]))

            Write-Verbose 'removing temp file'
            Remove-Item -Path $tempFile

            if ($PassTrough.IsPresent) {get-item $Path}
        }
    }
}

function Import-AWSOfferDataFile {
    [CmdletBinding()]
    [Parameter(ValueFromPipeline = $true)]
    param([string]$Path)
    
    process {
        Write-Verbose 'importing raw data'
        $script:rawAWSData = ConvertFrom-Csv ($sourceFile[5..($sourceFile.count)])

        Write-Verbose 'building index by location'
        $script:regionIDX = @{}
        foreach ($row in $script:rawAWSData) {
            if ($script:regionIDX.($row.Location)) {
                $script:regionIDX.($row.Location).Add($row) | Out-Null
            }
            else {
                $list = [System.Collections.ArrayList]::new()
                $list.Add($row) | Out-Null
                $script:regionIDX.($row.Location) = $list
            }
        }

    }
}

function Get-AWSCalcPrice {
    <#
      .SYNOPSIS
      This function  is used to analyze Azure Calc data extracted by the REST call 
      .DESCRIPTION
      This function  is used to analyze Azure Calc data extracted by the REST call. It can then filter the data by CPU, RAM, OS Type, VM  Size, Region
      
      .EXAMPLE
      Get-AWSOfferData -path e:\temp\awsdata1.csv -Verbose
      Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'US East (N. Virginia)' | ft -autosize
      
      .EXAMPLE
      Get-AWSOfferData -path e:\temp\awsdata1.csv -Verbose
      Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'US East (N. Virginia)' | ft -autosize

      .EXAMPLE
      Get-AzureCalcData
      Get-AzureCalcPrice -Region australia-east -Tier standard -Type windows | ft -AutoSize
      Get-AzureCalcPrice -CPU (8..16) -Region australia-east -Tier standard -Type windows | ft -AutoSize
      Get-AzureCalcPrice -CPU (8..16) -RAM (20..128) -Region australia-east -Tier standard -Type windows | sort  australia-east | ft -AutoSize

      .EXAMPLE
      Get-AzureCalcData
      Get-AzureCalcPrice -Size F8 -Region australia-east -Tier standard -Type windows | ft -AutoSize
      Get-AzureCalcPrice -Size F2 -Region australia-east -Tier standard -Type windows | ft -AutoSize
      Get-AzureCalcPrice -CPU (8..16) -RAM (20..40) -Region australia-east -Tier standard -Type windows | sort  australia-east | ft -AutoSize
      Get-AzureCalcPrice -CPU (2..16) -RAM (4..20) -Region australia-east -Tier standard -Type windows | sort  australia-east | ft -AutoSize
      Get-AzureCalcPrice -CPU (4..8) -RAM (4..32) -Region australia-east -Tier standard -Type windows | sort  australia-east | ft -AutoSize
  #>
    [cmdletbinding()]
    param (
        [int[]]$CPU, 
        [int[]]$RAM,
        [string]$Type,
        [string]$termType = 'ondemand',
        [string]$Size,
        [string[]]$Region,
        [string[]]$Tenancy = "Shared",
        $CalcData = $script:rawAWSData
    )
    begin {
        $cpuFilter = {param($objectSet)  $objectSet | Where-Object {$_.vCPU -in @($CPU)} }
        $ramFilter = {param($objectSet)  $objectSet | Where-Object {(($_.Memory) -replace ' GiB') -in @($ram)} }
        $typeFilter = {param($objectSet)  $objectSet | Where-Object {$_.'Operating System' -eq $Type} }
        $sizeFilter = {param($objectSet)  $objectSet | Where-Object {$_.'Instance Type' -eq $Size} }
        $tenancyFilter = {param($objectSet)  $objectSet | Where-Object {$_.Tenancy -eq $Tenancy} }
        $termTypeFilter = { param($objectSet)  $objectSet | Where-Object {$_.TermType -eq $TermType} }
        $regionFilter = {param($objectSet)   $regionIDX.$Region  } 
    }
    process {
        $filters = @()
        if ($Region) {
            $filters += $regionFilter 
        }

        if ($termType) {
            $filters += $termTypeFilter
        }

        if ($CPU) {
            $filters += $cpuFilter
        }
        if ($RAM) {
            $filters += $ramFilter
        }
        if ($Type) {
            $filters += $typeFilter
        }
        if ($Size) {
            $filters += $sizeFilter 
        }
        if ($Tenancy) {
            $filters += $tenancyFilter 
        }

        $ret = $CalcData
        foreach ($f in $filters) {
            write-verbose "$f"
            $ret = & $f $ret
            write-verbose "$($ret.Count)"
        }
        
        $ret
    }
}