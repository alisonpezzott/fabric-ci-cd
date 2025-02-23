# Parameters
$configsPath = "config.json"
$maxRetries = 10  # Maximum number of attempts
$retryInterval = 20  # Time between attempts in seconds
$resourceUrl = "https://api.fabric.microsoft.com"

# Enable or disable verbose logging
$verboseLogging = $false  # Set to $true for detailed logs

# Credentials
$tenantId = $env:FABRIC_TENANT_ID
$clientId = $env:FABRIC_CLIENT_ID
$clientSecret = $env:FABRIC_CLIENT_SECRET
$username = $env:FABRIC_AUTOMATION_USERNAME
$password = $env:FABRIC_AUTOMATION_USER_PASSWORD

# Function to get access token
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
        Write-Host "[INFO] Token obtained successfully."
        return $response.access_token
    } catch {
        Write-Host "[ERROR] Failed to obtain token: $($_.Exception.Message)"
        exit 1
    }
}

# Function to get current Git branch
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

# Function to get workspace ID from config file
function Get-WorkspaceIdFromFile {
    param ($branchName)

    if (-not (Test-Path $configsPath)) {
        Write-Host "[ERROR] Config file not found: $configsPath"
        exit 1
    }

    try {
        $config = Get-Content -Raw -Path $configsPath | ConvertFrom-Json
        $workspaceId = $config.$branchName.workspace_id

        if ($workspaceId) {
            return $workspaceId
        } else {
            Write-Host "[WARNING] Workspace ID not found for branch '$branchName'."
            exit 1
        }
    } catch {
        Write-Host "[ERROR] Failed to read config file: $($_.Exception.Message)"
        exit 1
    }
}

# Function to get Git status
function Get-GitStatus {
    param ($accessToken, $workspaceId)

    if (-not $workspaceId) {
        Write-Host "[ERROR] No workspace ID provided."
        return $null
    }

    $url = "$resourceUrl/v1/workspaces/$workspaceId/git/status"
    $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        Write-Host "[INFO] Git status retrieved successfully."
        
        if ($verboseLogging) {
            Write-Host "[DEBUG] Git Status: $($response | ConvertTo-Json -Depth 3)"
        }

        return $response
    } catch {
        Write-Host "[ERROR] Failed to get Git status: $($_.Exception.Message)"
        return $null
    }
}

# Function to update workspace
function Update-Workspace {
    param ($accessToken, $workspaceId)

    $attempt = 0
    while ($attempt -lt $maxRetries) {
        Write-Host "[INFO] Attempt $($attempt + 1)/${maxRetries}: Checking Git status..."
    
        $status = Get-GitStatus -accessToken $accessToken -workspaceId $workspaceId

        if (-not $status) {
            Write-Host "[WARNING] Failed to get Git status. Retrying..."
            Start-Sleep -Seconds $retryInterval
            $attempt++
            continue
        }

        # Extract commit hashes
        $remoteCommit = $status.remoteCommitHash
        $workspaceHead = if ($status.PSObject.Properties["workspaceHead"] -and $status.workspaceHead -ne "") { $status.workspaceHead } else { $null }

        Write-Host "[INFO] Remote Commit: $remoteCommit | Workspace Head: $workspaceHead"

        if ($remoteCommit -eq $workspaceHead) {
            Write-Host "[SUCCESS] Workspace is already up to date."
            exit 0
        }

        Write-Host "[INFO] Updating workspace..."

        $body = @{
            remoteCommitHash = $remoteCommit
            workspaceHead    = $workspaceHead
            conflictResolution = @{
                conflictResolutionPolicy = "PreferRemote"
                conflictResolutionType = "Workspace"
            }
            options         = @{ 
                allowOverrideItems = $true 
            }
        } | ConvertTo-Json -Depth 3

        $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }
        $url = "$resourceUrl/v1/workspaces/$workspaceId/git/updateFromGit"

        try {
            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType "application/json"
            Write-Host "[SUCCESS] Update request sent successfully."
        } catch {
            Write-Host "[ERROR] Failed to update workspace: $($_.Exception.Message)"
            Start-Sleep -Seconds $retryInterval
            $attempt++
            continue
        }

        # Wait before rechecking status
        Write-Host "[INFO] Waiting $retryInterval seconds before checking status..."
        Start-Sleep -Seconds $retryInterval

        # Recheck Git status
        $statusAfterUpdate = Get-GitStatus -accessToken $accessToken -workspaceId $workspaceId

        if ($statusAfterUpdate -and ($statusAfterUpdate.remoteCommitHash -eq $statusAfterUpdate.workspaceHead)) {
            Write-Host "[SUCCESS] Update successful. Workspace is now up to date."
            exit 0
        } else {
            Write-Host "[WARNING] Update not reflected yet. Retrying..."
            $attempt++
        }
    }

    Write-Host "[ERROR] Max retries reached. The workspace may still be updating."
    exit 1
}

# Execution
$accessToken = Get-AccessToken
$branchName = Get-CurrentGitBranch
$workspaceId = Get-WorkspaceIdFromFile -branchName $branchName
Update-Workspace -accessToken $accessToken -workspaceId $workspaceId
