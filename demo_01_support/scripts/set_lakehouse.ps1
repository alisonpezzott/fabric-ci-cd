# Parameters
$configPath = "config.json"
$maxRetries = 10
$retryInterval = 10

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
        scope         = "https://analysis.windows.net/powerbi/api/.default"
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

# Get current Git branch
function Get-CurrentGitBranch {
    $branch = $env:BUILD_SOURCEBRANCH -replace "refs/heads/", ""
    
    if (-not $branch) {
        try {
            $branch = git rev-parse --abbrev-ref HEAD
        } catch {
            $branch = "default"
        }
    }

    if ($branch -eq "main") { $branch = "prod" }
    return $branch.ToLower()
}

# Load workspace_id from config
function Get-WorkspaceIdFromFile {
    if (-not (Test-Path $configPath)) {
        Write-Host "Config file not found: $configPath"
        return $null, @{}
    }

    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        $workspaceId = $config.$branchName.workspace_id
        $lakehouseName = $config.$branchName.lakehouse_name
        return $workspaceId, $lakehouseName, $config
    } catch {
        Write-Host "Error reading config file: $_"
        return $null, @{}
    }
}

# Check if Lakehouse exists
function Check-LakehouseExists {
    param (
        [string]$accessToken,
        [string]$workspaceId,
        [string]$lakehouseName
    )

    $url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/lakehouses"
    $headers = @{ 
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json" 
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

        if ($response.value) {
            $lakehouse = $response.value | Where-Object { $_.displayName -eq $lakehouseName }

            if ($lakehouse) {
                Write-Host "Lakehouse was found: $lakehouseName - ID: $($lakehouse.id)"
                return $lakehouse.id
            } else {
                Write-Host "Lakehouse '$lakehouseName' not found."
                return $null
            }
        } else {
            Write-Host "Any Lakehouse found in workspace $workspaceId."
            return $null
        }
    } catch {
        Write-Host "Error checking Lakehouse: $_"
        return $null
    }
}

# Create or update lakehouse
function New-OrUpdateLakehouse {
    param (
        [string]$accessToken,
        [string]$workspaceId,
        [hashtable]$configData
    )

    $url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/lakehouses"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    try {
        $payload = @{ "displayName" = $lakehouseName; "description" = "" } | ConvertTo-Json -Depth 2
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $payload
        Write-Host "Lakehouse created successfully. ID: $($response.id)"
        return $response.id
    } catch {
        Write-Host "Error to create lakehouse: $_"
        return $null
    }
}

# Update config
function Update-WorkspaceConfig {
    param ($branchName, $newData)

    $config = @{}

    if (Test-Path $configPath) {
        try {
            $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
            Write-Host "Configs loaded from $configPath"
        } catch {
            Write-Host "Error reading JSON, creating new config."
        }
    }

    if (-not $config.$branchName) {
        $config | Add-Member -MemberType NoteProperty -Name $branchName -Value @{}
    }

    foreach ($key in $newData.Keys) {
        $config.$branchName | Add-Member -MemberType NoteProperty -Name $key -Value $newData[$key] -Force
    }

    try {
        $config | ConvertTo-Json -Depth 2 | Set-Content -Path $configPath
        Write-Host "Config file updated for branch '$branchName'."
    } catch {
        Write-Host "Error saving config file: $_"
        exit 1
    }
}

# Get connection string of Lakehouse
function Get-ConnectionString {
    param ($accessToken, $workspaceId, $lakehouseId, $branchName)

    $attempt = 0
    while ($attempt -lt $maxRetries) {
        Write-Host "Attempt $($attempt + 1)/$($maxRetries): Checking connection string..."

        $url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/lakehouses/$lakehouseId"
        $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }

        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
            $sqlProperties = $response.properties.sqlEndpointProperties
            
            if ($sqlProperties.connectionString) {
                       
                $newData = @{
                    "sql_connection_string" = $sqlProperties.connectionString
                    "sql_lakehouse_id"      = $sqlProperties.id
                }

                Update-WorkspaceConfig -branchName $branchName -newData $newData
                Write-Host "Lakehouse connection string saved."
                exit 0
            }
        } catch {
            Write-Host "Error retrieving connection string: $_"
        }

        Start-Sleep -Seconds $retryInterval
        $attempt++
    }

    Write-Host "Max retries reached. Connection string not retrieved."
    exit 1
}

# Convert PSCustomObject to Hashtable
function ConvertTo-Hashtable {
    param ($object)

    $hashTable = @{}
    foreach ($property in $object.PSObject.Properties) {
        if ($property.Value -is [PSCustomObject]) {
            $hashTable[$property.Name] = ConvertTo-Hashtable -object $property.Value
        } else {
            $hashTable[$property.Name] = $property.Value
        }
    }
    return $hashTable
}


# Execution
$accessToken = Get-AccessToken
$branchName = Get-CurrentGitBranch
$workspaceId, $lakehouseName, $configDataRaw = Get-WorkspaceIdFromFile
$configData = ConvertTo-Hashtable -object $configDataRaw  # Conversion to Hashtable

# First check if exists
$lakehouseId = Check-LakehouseExists -accessToken $accessToken -workspaceId $workspaceId -lakehouseName $lakehouseName

# If not exists create
if (-not $lakehouseId) {
    $lakehouseId = New-OrUpdateLakehouse -accessToken $accessToken -workspaceId $workspaceId -configData $configData
}

Write-Output "Lakehouse ID: $lakehouseId"

Update-WorkspaceConfig -branchName $branchName -newData @{ "lakehouse_id" = $lakehouseId }
Get-ConnectionString -accessToken $accessToken -workspaceId $workspaceId -lakehouseId $lakehouseId -branchName $branchName
