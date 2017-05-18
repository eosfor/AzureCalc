function Get-AzureCalcTier($AzureCalcData = $script:rawdata) {
    $AzureCalcData.Tiers
}

function Get-AzureCalcType($AzureCalcData = $script:rawdata) {
    $AzureCalcData.Types
}

function Get-AzureCalcSize($AzureCalcData = $script:rawdata) {
    $AzureCalcData.Sizes
}

function Get-AzureCalcSoftwareLicense($AzureCalcData = $script:rawdata) {
    $AzureCalcData.softwareLicenses
}

function Get-AzureCalcRegion($AzureCalcData = $script:rawdata) {
    $AzureCalcData.regions
}

function Get-AzureCalcData {
    [CmdletBinding()]
    param()
    $request = Invoke-WebRequest -Uri https://azure.microsoft.com/api/v1/pricing/virtual-machines/calculator/?culture=en-us
    Set-Variable -Name rawdata -Value  ($request.Content | ConvertFrom-Json) -Option ReadOnly -Scope script
  
    if ($script:rawdata) {
        $script:calcdata = @()
        foreach ($type in Get-AzureCalcType) {
            foreach ($size in Get-AzureCalcSize) {
                foreach ($tier in Get-AzureCalcTier) {
                    $indexName = "$($type.slug)-$($size.slug)-$($tier.slug)"
                    if ($script:rawdata.offers.$indexName) {
                        $script:calcdata += 
                        [pscustomobject]@{
                            Cores    = $script:rawdata.offers.$indexName.cores
                            Ram      = $script:rawdata.offers.$indexName.Ram
                            DiskSize = $script:rawdata.offers.$indexName.DiskSize
                            Prices   = $script:rawdata.offers.$indexName.Prices
                            Skus     = $script:rawdata.offers.$indexName.Skus
                            Type     = $type.slug
                            Size     = $size.slug
                            Tier     = $tier.slug
                            Index    = $indexName
                            DisplayName = "$($tier.Displayname)_$($size.Displayname -replace " ", "_")"
                        }
                    }
                }
            }
        }
    }


}

function Get-AzureCalcPrice {
  <#
      .SYNOPSIS
      This function  is used to analyze Azure Calc data extracted by the REST call 
      .DESCRIPTION
      This function  is used to analyze Azure Calc data extracted by the REST call. It can then filter the data by CPU, RAM, OS Type, VM  Size, Region
      
      .EXAMPLE
      Get-AzureCalcData
      Get-AzureCalcPrice -Size A4v2 -Region asia-pacific-southeast, canada-east, us-east, us-west | ft -AutoSize
      
      .EXAMPLE
      $r = 'us-east', 'us-east-2'
      Get-AzureCalcPrice   -Region $r -CPU 3 -ram 10 -Type windows -Tier standard -ShowClosestMatch | ft -AutoSize
      Get-AzureCalcPrice   -Region $r -CPU 8 -ram 14 -Type windows -Tier standard | ft -AutoSize

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
  [cmdletbinding(DefaultParameterSetName="Region")]
  param (
    [Parameter(ParameterSetName = "hardware")]
    [int[]]$CPU, 
    
    [Parameter(ParameterSetName = "hardware")]
    [int[]]$RAM,
    
    [Parameter(ParameterSetName = "hardware")]
    [Parameter(ParameterSetName = "size")]
    [Parameter(ParameterSetName = "Region")]
    [ValidateScript( {$_ -in (Get-AzureCalcType).slug})]
    [string]$Type,
    
    [Parameter(ParameterSetName = "size")]
    [ValidateScript( {$_ -in (Get-AzureCalcSize).slug})]
    [string]$Size,
    
    [Parameter(ParameterSetName = "hardware")]
    [Parameter(ParameterSetName = "size")]
    [Parameter(ParameterSetName = "Region")]
    [ValidateScript( {$_ -in (Get-AzureCalcRegion).slug})]
    [string[]]$Region,

    [Parameter(ParameterSetName = "hardware")]
    [Parameter(ParameterSetName = "size")]
    [Parameter(ParameterSetName = "Region")]
    [ValidateScript( {$_ -in (Get-AzureCalcTier).slug})]
    [string[]]$Tier = "standard",
   
    [Parameter(mandatory = $false)]
    [Parameter(ParameterSetName = "hardware")]
    [switch]$ShowClosestMatch,
    
    [Parameter(mandatory = $false)] 
    [Parameter(ParameterSetName = "hardware")]
    [Parameter(ParameterSetName = "size")]
    [Parameter(ParameterSetName = "Region")]
    $CalcData = $script:calcdata
  )
  begin {
    function getClosest ($objectList, $propName, $num) {
      $diff = [math]::Abs(($num - ($objectList.$propName)[0]))
      $objectList | ForEach-Object {$r = @{}} {
        $currObj = $_
        $curr = $_.$propName
        $num | ForEach-Object {
          $abs = [math]::Abs(($_ - $curr))
          $r.$Abs = $r.$Abs + @($currObj)        
        }
      } { 
        $minValueKey = ($r.Keys | Sort-Object | Select-Object -First 1)
        $minByProperty = $r[$minValueKey] | Where-Object "$propname" -le $num #first try to pick lower value
        if (! $minByProperty ) {$minByProperty = $r[$minValueKey] | Where-Object "$propname" -ge $num} #if it does not exist picking higher value
        $minByProperty
      }
    }
    $cpuFilter = if (! $ShowClosestMatch.IsPresent) {{param($objectSet)  $objectSet | Where-Object {$_.Cores -in @($CPU)} }} 
    else { {
        param($objectSet) 
        $t = getClosest $objectSet 'Cores' $CPU
        $t} }
    $ramFilter = if (! $ShowClosestMatch.IsPresent) {{param($objectSet)  $objectSet | Where-Object {$_.Ram -in @($RAM)} }}
    else { {
        param($objectSet) 
        $t = getClosest $objectSet 'Ram' $RAM 
        $t}  }
    $typeFilter = {param($objectSet)  $objectSet | Where-Object {$_.Type -eq $Type} }
    $sizeFilter = {param($objectSet)  $objectSet | Where-Object {$_.Size -eq $Size} }
    $tierFilter = {param($objectSet)  $objectSet | Where-Object {$_.Tier -eq $Tier} }
    $regionFilter = {param($objectSet)  $objectSet | Where-Object { [bool]$r -OR ($Region | ForEach-Object {$_.Prices.keys -contains $_ }); $r } } 
  }
  process {
    $filters = @()
    if ($Region) {
      $filters += $regionFilter 
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
    if ($Tier) {
      $filters += $tierFilter 
    }
    
    
    $ret = $CalcData
    foreach ($f in $filters) {
      $ret = & $f $ret
    }
    
    if ($Region) {
      foreach ($el in $ret) {
        $res = [ordered]@{
          Index    = $el.index
          Type     = $el.type
          Size     = $el.size
          Tier     = $el.Tier
          Cores    = $el.Cores
          Ram      = $el.Ram
          DiskSize = $el.DiskSize
          DisplayName = $el.DisplayName
        }
          
        foreach ($r in $Region) {
          $res.$r = $el.Prices.$r
        }
        
        
        $typedRet = [pscustomobject] $res
        $typedRet.psobject.TypeNames.Insert(0, "AzureCalc.PriceEntry")
        $typedRet
      }
    }
    else {
            $typedRet = $ret
            $typedRet.psobject.TypeNames.Insert(0, "AzureCalc.PriceEntry")
            $typedRet
        }
    }
}