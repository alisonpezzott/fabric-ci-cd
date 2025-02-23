# Parameters
$configPath = "config.json"

# Credencials
$tenantId = $env:FABRIC_TENANT_ID
$clientId = $env:FABRIC_CLIENT_ID
$clientSecret = $env:FABRIC_CLIENT_SECRET
$username = $env:FABRIC_USERNAME
$automationUsername = $env:FABRIC_AUTOMATION_USERNAME

$administrators = @(
    $username , 
    $automationUsername
)

# Get IDs from config file
function Get-IdsFromConfigFile {
    if (-not (Test-Path $configPath)) {
        Write-Host "Config file not found: $configPath"
        return $null, @{ }
    }

    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        $workspaceName = $config.$branchName.workspace_name
        $workspaceId = $config.$branchName.workspace_id
        $project = $config.global.project
        $capacityId = $config.global.capacity_id
        return $workspaceName, $workspaceId, $project, $capacityId, $config
    } catch {
        Write-Host "Error reading config file: $_"
        return $null, $null, $null, @{ }
    }
}

# Get access token
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

# Check if Workspace exists (fix pagination issue)
function Get-WorkspaceId {
    param ($accessToken, $workspaceName)

    $headers = @{ "Authorization" = "Bearer $accessToken" }
    $url = "https://api.powerbi.com/v1.0/myorg/groups?top=5000"  # Pega até 5000 workspaces

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $workspace = $response.value | Where-Object { $_.name -eq $workspaceName -or $_.name.Trim() -eq $workspaceName.Trim() }

        if ($workspace) {
            Write-Host "Workspace '$workspaceName' found. ID: $($workspace.id)"
            return $workspace.id
        } else {
            Write-Host "Workspace '$workspaceName' not found."
            return $null
        }
    } catch {
        Write-Host "Error getting workspaces: ${_}"
        exit 1
    }
}

# Ensure workspace exists or create it
function New-Workspace {
    param ($accessToken, $workspaceName)

    $existingWorkspaceId = Get-WorkspaceId -accessToken $accessToken -workspaceName $workspaceName

    if ($existingWorkspaceId) {
        Write-Host "Workspace '$workspaceName' already exists with ID: $existingWorkspaceId"
        return $existingWorkspaceId
    } else {
        Write-Host "Creating workspace '$workspaceName'..."
        $url = "https://api.powerbi.com/v1.0/myorg/groups"
        $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }
        $data = @{ "name" = $workspaceName; "capacityId" = $capacityId } | ConvertTo-Json -Depth 2

        try {
            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $data
            $workspaceId = $response.id
            Write-Host "Workspace '$workspaceName' created. ID: $workspaceId"
            return $workspaceId
        } catch {
            if ($_.ErrorDetails.Message -match "PowerBIEntityAlreadyExists") {
                Write-Host "Warning: Workspace already exists, but was not found in the initial check. Retrieving ID..."
                return Get-WorkspaceId -accessToken $accessToken -workspaceName $workspaceName
            } else {
                Write-Host "Error creating workspace: ${_}"
                exit 1
            }
        }
    }
}

# Add admins if not already present
function Add-AdminToWorkspace {
    param ([string]$workspaceId, [string]$accessToken, [array]$administrators)

    $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }

    foreach ($admin in $administrators) {
        $url = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/users"
        $data = @{ "identifier" = $admin; "groupUserAccessRight" = "Admin"; "principalType" = "User" } | ConvertTo-Json -Depth 2

        try {
            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $data
            Write-Host "User $admin added as admin to workspace."
        } catch {
            Write-Host "Error adding user $($admin): ${_}"
        }
    }
}

# Assign capacity if not already assigned
function Set-CapacityToWorkspace {
    param ($workspaceId, $accessToken, $capacityId)

    $url = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/AssignToCapacity"
    $headers = @{ "Authorization" = "Bearer $accessToken"; "Content-Type" = "application/json" }
    $data = @{ "capacityId" = $capacityId } | ConvertTo-Json -Depth 2

    try {
        Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $data
        Write-Host "Capacity assigned to workspace '$workspaceId'."
    } catch {
        Write-Host "Error assigning capacity: ${_}"
    }
}

# Update config.json
function Update-WorkspaceConfig {
    param ([string]$branchName, [string]$workspaceId)

    $config = @{ }

    if (Test-Path $configPath) {
        try {
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            Write-Host "Configs loaded from $configPath"
        } catch {
            Write-Host "Error reading JSON, creating new config."
            $config = @{ }
        }
    }

    if (-not $config.PSObject.Properties[$branchName]) {
        $config | Add-Member -MemberType NoteProperty -Name $branchName -Value ([PSCustomObject]@{ })
    }

    $config.$branchName.workspace_id = $workspaceId

    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
        Write-Host "Workspace ID saved in '$configPath' for branch '$branchName'."
    } catch {
        Write-Host "Error saving config file: ${_}"
        exit 1
    }
}

# Execution
$branchName = Get-CurrentGitBranch
$workspaceName, $workspaceId, $project, $capacityId, $config = Get-IdsFromConfigFile
$accessToken = Get-AccessToken

# Ensure workspace exists
$workspaceId = New-Workspace -accessToken $accessToken -workspaceName $workspaceName

# Ensure permissions and capacity are assigned
Add-AdminToWorkspace -workspaceId $workspaceId -accessToken $accessToken -administrators $administrators
Set-CapacityToWorkspace -workspaceId $workspaceId -accessToken $accessToken -capacityId $capacityId

# Update configuration file
Update-WorkspaceConfig -branchName $branchName -workspaceId $workspaceId
