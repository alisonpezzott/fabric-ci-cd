# Parameters
$configsPath = "config.json"
$resourceUrl = "https://api.fabric.microsoft.com"

# Credencials
$tenantId = $env:FABRIC_TENANT_ID
$clientId = $env:FABRIC_CLIENT_ID
$clientSecret = $env:FABRIC_CLIENT_SECRET
$username = $env:FABRIC_AUTOMATION_USERNAME
$password = $env:FABRIC_AUTOMATION_USER_PASSWORD

# Get acess token with username and password
function Get-AccessToken {
    $url = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    $body = @{
        grant_type    = "password"
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://api.fabric.microsoft.com/.default"
        username      = $username
        password      = $password
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body
        Write-Host "Token obtained successfully."
        return $response.access_token
    } catch {
        Write-Host "Error obtaining the token: ${_}"
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

# Get workspace_id from config
function Get-WorkspaceIdFromFile {
    param ([string]$branchName)

    if (-not (Test-Path $configsPath)) {
        Write-Host "Error: config.json not found."
        exit 1
    }

    try {
        $config = Get-Content -Raw -Path $configsPath | ConvertFrom-Json
        $workspaceId = $config.$branchName.workspace_id

        if ($workspaceId) {
            return $workspaceId
        } else {
            Write-Host "Warning: Workspace ID not found for branch '$branchName'."
            exit 1
        }
    } catch {
        Write-Host "Error reading config file: ${_}"
        exit 1
    }
}

# Commit from workspace to Git
function Publish-FromWsToGit {
    param ([string]$accessToken, [string]$workspaceId)

    $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }
    $body = @{ "mode" = "All" } | ConvertTo-Json -Depth 2
    $url = "$resourceUrl/v1/workspaces/$workspaceId/git/commitToGit"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
        
        # Validation if response has headers before request
        if ($response.PSObject.Properties['headers']) {
            $operationId = $response.headers["x-ms-operation-id"]
            $retryAfter = $response.headers["Retry-After"]
            Write-Host "Update started successfully! Operation ID: $operationId, Retry-After: $retryAfter sec"
        } else {
            Write-Host "Commit request was successful, but no operation ID was returned."
        }
    } catch {
        Write-Host "Error updating workspace. Full response: $_"
        exit 1
    }
}

# Execution
$branchName = Get-CurrentGitBranch
$workspaceId = Get-WorkspaceIdFromFile -branchName $branchName
$accessToken = Get-AccessToken
Publish-FromWsToGit -accessToken $accessToken -workspaceId $workspaceId
