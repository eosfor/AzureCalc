$script:awsRaw = @{}

function Get-AWSCalcRegion($AzureCalcData = $script:awsRaw) {
    $AzureCalcData.Keys
}

function Get-AWSOfferData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [switch]$Force,
        [switch]$PassThru
    )
    process {
        if (Test-Path $Path) {
            if (! $Force.IsPresent) {
                Throw "File exists, please use -Force to override"
            }
        }
        $baseURL = 'https://pricing.us-east-1.amazonaws.com'
        $awsIndex = Invoke-RestMethod -Method Get -URI "$baseURL/offers/v1.0/aws/index.json"
        $awsRegionIndex = Invoke-RestMethod -Method Get -URI "$baseURL$($awsIndex.offers.AmazonEC2.currentRegionIndexUrl)"

        #create runspace factory
        $pool = [runspacefactory]::CreateRunspacePool(1, 10)
        $pool.open()

        #start tasks
        $tasks =
        ($awsRegionIndex.regions | Get-Member -MemberType NoteProperty).Name |
            ForEach-Object {
                $region = $_
                $regionUrl = $awsRegionIndex.regions.$_.currentVersionUrl -replace 'json', 'csv'

                $p = [powershell]::Create().AddCommand('Invoke-WebRequest').Addparameter("Method", "Get").Addparameter("URI", ($baseurl + $regionUrl)).Addparameter("OutFile", (Join-Path $Path "$region.csv"))
                $p.RunspacePool = $pool
                $ia = $p.BeginInvoke()
                @{p = $p; ia = $ia; path = (Join-Path $Path "$region.csv")}
                #Invoke-WebRequest -Method Get -URI ($baseurl + $regionUrl) -OutFile (Join-Path $Path "$region.csv")
            }

        #wait for completion
        foreach ($t in $tasks) {
            $t.p.EndInvoke($t.ia)
            $sourceFile = [System.IO.File]::ReadAllLines($t.path)
            [System.IO.File]::WriteAllLines($t.path, ($sourceFile[5..($sourceFile.count)]))

            $t.p.Dispose()
        }

        #return HT if needed
        if ($PassThru.IsPresent) {get-item $Path}
    }
}

function Import-AWSOfferDataFile {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_})]
        [string]$Path,
        [Parameter()]
        [switch]$PassThru
    )

    process {
        Write-Verbose 'importing raw data from $path'

        $fileCount = (dir $Path -File).Count
        $i = 0

        foreach ($file in (Get-ChildItem $path -File)) {
            Write-Progress -Activity "Importing $($file.fullname)" -PercentComplete ((++$i/$filecount)*100)
            $region = $file.Name -replace '.csv'
            #$dt = Get-Content $file.fullname -ReadCount 0 | ConvertFrom-Csv | Out-DataTable
            $gpa = [GenericParsing.GenericParserAdapter]::new($file.fullname)
            $gpa.FirstRowHasHeader = $true
            $dt = $gpa.GetDataTable()
            foreach ($row in $dt) {
                $row.psobject.TypeNames.Insert(0, "AWSCalc.DataRow")
            }
            $script:awsRaw.$region = $dt
        }

        if ($PassThru.IsPresent) {$awsRaw}
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
      Get-AWSCalcPrice -CPU  8 -RAM  (8..32) -Region 'us-east-1' | ft -autosize

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
        $regionFilter = {param($objectSet) $Region | ForEach-Object {$script:awsRaw.$_} }
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