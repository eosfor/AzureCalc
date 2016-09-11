$script:request = Invoke-WebRequest -Uri https://azure.microsoft.com/api/v1/pricing/virtual-machines/calculator/?culture=en-us
$script:offers = $script:request.Content | ConvertFrom-Json


function Get-AzureVMPrice
{
  [CmdletBinding()]
  [OutputType([double])]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory=$false, Position=0)]
    $Cores,
    [Parameter(Mandatory=$false, Position=1)]
    [double]$Ram,
    [Parameter(Mandatory=$false, Position=2)]
    $Location,
    [Parameter(Mandatory=$false, Position=3)]
    $OS
  )

  Begin
  {
    $coresList = @{}
    $ramList = @{}
    ($script:offers.offers | Get-Member -MemberType Properties).Name |  ForEach-Object {$coresList[[int]"$($offers.offers."$_".cores)"] += [array]($offers.offers."$_")}
    ($script:offers.offers | Get-Member -MemberType Properties).Name |  ForEach-Object {$ramList[[double]"$($offers.offers."$_".ram)"] += [array]($offers.offers."$_")}
    $slug = ($script:offers.regions | Where-Object displayName -EQ $Location).slug
  }
  Process
  {
    if($PSBoundParameters.ContainsKey("Cores")){
      $mCores = $coresList.keys | Sort-Object | Where-Object {$_ -ge $Cores} | Sort-Object | Select-Object -first 1 # all having $cores
      $rCores = $mCores | ForEach-Object {$coresList[$_]}
      
      $rCores
    }
    
    if($PSBoundParameters.ContainsKey("Ram")){
      [double]$mRam = $ramList.keys | Sort-Object | Where-Object {$_ -ge $Ram}  | Sort-Object | Select-Object -first 1 # all having $ram
      $rRam = $mRam | ForEach-Object {$ramList[$_]}
      
      $rRam
    }

    
    
    #    $mCores | Select-Object -First 1 | ForEach-Object {$coresList[$_]} | Sort-Object ram | Where-Object {$_.ram -ge $Ram} | 
    #    Select-Object -First 1 | Select-Object -ExpandProperty prices | 
    #    Select-Object -Expand "$slug`-$OS"
  }
}



#Get-AzureVMPrice -Cores 16 -Ram 125 -Location "East US" -OS "Windows"

#Get-AzureVMPrice -Cores 16
Get-AzureVMPrice -Ram 32