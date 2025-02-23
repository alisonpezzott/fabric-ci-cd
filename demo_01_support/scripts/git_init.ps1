# Parameters
$configsPath = "config.json"
$adoOrganization = "alisonpezzott"
$adoProject = "ci_cd_demo"
$adoRepo = "ci_cd_demo"
$gitFolder = "fabric"
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

# Get workspace_id from config
function Get-WorkspaceIdFromFile {
    param ($branchName)

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
        Write-Host "Error reading config file: $_"
        exit 1
    }
}

# Connect workspace to Git
function Connect-Git {
    param ([string]$accessToken, [string]$workspaceId, [string]$branchName)

    if ($branchName -eq "prod") { $branchName = "main" }

    $body = @{
        gitProviderDetails = @{
            gitProviderType  = "AzureDevOps"
            organizationName = $adoOrganization
            projectName      = $adoProject
            repositoryName   = $adoRepo
            branchName       = $branchName
            directoryName    = $gitFolder
        }
    } | ConvertTo-Json -Depth 2

    $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }
    $url = "$resourceUrl/v1/workspaces/$workspaceId/git/connect"

    try {
        Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
        Write-Host "Git connection request sent successfully."
    } catch {
        Write-Host "Error connecting workspace to Git: $_"
        exit 1
    }
}

# Initialize connection of Fabric with Git
function Initialize-Git {
    param ([string]$accessToken, [string]$workspaceId)

    $body = @{ initializationStrategy = "PreferRemote" } | ConvertTo-Json -Depth 2
    $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }
    $url = "$resourceUrl/v1/workspaces/$workspaceId/git/initializeConnection"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
        if ($response.StatusCode -eq 202) {
            $operationId = $response.Headers["x-ms-operation-id"]
            $retryAfter = $response.Headers["Retry-After"]
            Write-Host "Connection initialized successfully! Operation ID: $operationId, Retry-After: $retryAfter sec"
        } elseif ($response.StatusCode -eq 200) {
            Write-Host "Connection initialized successfully with status code 200."
        }
    } catch {
        Write-Host "Error initializing connection: $_"
        exit 1
    }
}

# Execution
$branchName = Get-CurrentGitBranch
$workspaceId = Get-WorkspaceIdFromFile -branchName $branchName
$accessToken = Get-AccessToken
Connect-Git -accessToken $accessToken -workspaceId $workspaceId -branchName $branchName
Initialize-Git -accessToken $accessToken -workspaceId $workspaceId
