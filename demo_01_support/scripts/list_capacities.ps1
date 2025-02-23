# Credencials
$tenantId = $env:FABRIC_TENANT_ID
$clientId = $env:FABRIC_CLIENT_ID
$clientSecret = $env:FABRIC_CLIENT_SECRET

# Get access token with Service Principal
function Get-AccessToken {
    $url = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://api.fabric.microsoft.com/.default"
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body
        Write-Host "Token obtained successfully."
        return $response.access_token
    } catch {
        Write-Host "Error obtaining the token: $_"
        exit 1
    }
}

# List capacities of Tenant
function Get-Capacities {
    param (
        [string]$accessToken
    )

    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    $url = "https://api.fabric.microsoft.com/v1/capacities"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        if ($response.PSObject.Properties['value']) {
            return $response.value
        } else {
            Write-Host "Error getting capacities: $($response | ConvertTo-Json -Depth 2)"
            exit 1
        }
    } catch {
        Write-Host "Error calling Fabric API: $_"
        exit 1
    }
}

# Execution
$accessToken = Get-AccessToken
$capacities = Get-Capacities -accessToken $accessToken

# Better format with JSON
$capacities | ConvertTo-Json -Depth 2 | Write-Host
