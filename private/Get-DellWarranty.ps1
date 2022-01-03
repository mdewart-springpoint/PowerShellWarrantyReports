function get-DellWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    if ($null -eq $Script:DellClientID) {
        Write-Error "Cannot continue: Dell API information not found. Please run Set-WarrantyAPIKeys before checking Dell Warranty information."
        return  [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information - No API key'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information - No API key'
            'Client'                = $Client
        }
    } 
    $today = Get-Date -Format yyyy-MM-dd
    $AuthURI = "https://apigtwb2c.us.dell.com/auth/oauth/v2/token"
    if ($Script:TokenAge -lt (Get-Date).AddMinutes(-55)) {
        $Script:Token = $null 
    }
    If ($null -eq $Script:Token) {
        $OAuth = "$Script:DellClientID`:$Script:DellClientSecret"
        $Bytes = [System.Text.Encoding]::ASCII.GetBytes($OAuth)
        $EncodedOAuth = [Convert]::ToBase64String($Bytes)
        $headersAuth = @{ "authorization" = "Basic $EncodedOAuth" }
        $Authbody = 'grant_type=client_credentials'
        $AuthResult = Invoke-RestMethod -Method Post -Uri $AuthURI -Body $AuthBody -Headers $HeadersAuth
        $Script:token = $AuthResult.access_token
        $Script:TokenAge = (Get-Date)
    }

    $headersReq = @{ "Authorization" = "Bearer $Script:Token" }
    $ReqBody = @{ servicetags = $SourceDevice }
    $WarReq = Invoke-RestMethod -Uri "https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements" -Headers $headersReq -Body $ReqBody -Method Get -ContentType "application/json"
    $warlatest = $warreq.entitlements.enddate | Sort-Object | Select-Object -Last 1 
    $WarrantyState = if ($warlatest -le $today) {
        "Expired" 
    } else {
        "OK" 
    }
    if ($warlatest) {
        $StartDate = $warreq.entitlements.startdate | ForEach-Object { [DateTime]$_ } | Sort-Object -Descending | Select-Object -Last 1
        $EndDate = $warreq.entitlements.enddate | ForEach-Object { [DateTime]$_ } | Sort-Object -Descending | Select-Object -First 1
        $ShipDate = $WarReq.ShipDate | ForEach-Object { [DateTime]$_ } | Sort-Object -Descending | Select-Object -First 1
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = $warreq.entitlements.serviceleveldescription -join "`n"
            'ShipDate'              = $ShipDate
            'StartDate'             = $StartDate
            'EndDate'               = $EndDate
            'Warranty Status'       = $WarrantyState
            'Client'                = $Client
        }
    } else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'ShipDate'              = $ShipDate
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
            'Client'                = $Client
        }
    }
    return $WarObj
}