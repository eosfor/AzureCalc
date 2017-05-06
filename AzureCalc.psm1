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
                Cores = $script:rawdata.offers.$indexName.cores
                Ram = $script:rawdata.offers.$indexName.Ram
                DiskSize = $script:rawdata.offers.$indexName.DiskSize
                Prices = $script:rawdata.offers.$indexName.Prices
                Skus = $script:rawdata.offers.$indexName.Skus
                Type = $type.slug
                Size = $size.slug
                Tier = $tier.slug
                Index = $indexName
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
  #>
  [cmdletbinding()]
  param (
    [Parameter()]
    [int]$CPU, 
    
    [Parameter()]
    [int]$RAM,
    
    [Parameter()]
    [ValidateScript({$_ -in (Get-AzureCalcType).slug})]
    [string]$Type,
    
    [Parameter()]
    [ValidateScript({$_ -in (Get-AzureCalcSize).slug})]
    [string]$Size,
    
    [Parameter()]
    [ValidateScript({$_ -in (Get-AzureCalcRegion).slug})]
    [string[]]$Region,
    
    [Parameter(mandatory = $false)] 
    $CalcData =  $script:calcdata
  )
  begin{
    $cpuFilter = {param($objectSet)  $objectSet | ? {$_.Cores -eq $CPU} } 
    $ramFilter = {param($objectSet)  $objectSet | ? {$_.Ram -eq $RAM} }
    $typeFilter = {param($objectSet)  $objectSet | ? {$_.Type -eq $Type} }
    $sizeFilter = {param($objectSet)  $objectSet | ? {$_.Size -eq $Size} }
    $regionFilter = {param($objectSet)  $objectSet | ? { [bool]$r -OR ($Region | % {$_.Prices.keys -contains $_ }); $r } } 
  }
  process{
    $filters = @()
    if ($CPU){
      $filters += $cpuFilter
    }
    if ($RAM){
      $filters += $ramFilter
    }
    if ($Type){
      $filters += $typeFilter
    }
    if ($Size){
      $filters += $sizeFilter 
    }
    
    if ($Region){
      $filters += $regionFilter 
    }
    
    $ret = $CalcData
    foreach ($f in $filters){
      $ret = & $f $ret
    }
    
    if ($Region) {
      foreach ($el in $ret) {
        $res =  [ordered]@{
          Index = $el.index
          Type = $el.type
          Size = $el.size
          Cores = $el.Cores
          Ram = $el.Ram
          DiskSize = $el.DiskSize          
        }
          
        foreach ($r in $Region){
          $res.$r = $el.Prices.$r
        }
          
        [pscustomobject] $res
      }
    }
    else{
      $ret
    }
  }
}
