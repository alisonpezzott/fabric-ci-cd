# Parameters
$configsPath = "config.json"
$resourceUrl = "https://api.fabric.microsoft.com"

# Credentials
$tenantId = $env:FABRIC_TENANT_ID
$clientId = $env:FABRIC_CLIENT_ID
$clientSecret = $env:FABRIC_CLIENT_SECRET
$username = $env:FABRIC_AUTOMATION_USERNAME
$password = $env:FABRIC_AUTOMATION_USER_PASSWORD

# Get access token using username and password
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

# Get the current Git branch
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

# Retrieve workspace_id and pipeline_name from the config file
function Get-IdsFromFile {
    param ($branchName)

    if (-not (Test-Path $configsPath)) {
        Write-Host "Error: config.json not found."
        exit 1
    }

    try {
        $config = Get-Content -Raw -Path $configsPath | ConvertFrom-Json
        $workspaceId = $config.$branchName.workspace_id
        $pipelineName = $config.$branchName.pipeline_name

        if ($workspaceId -and $pipelineName) {
            return $workspaceId, $pipelineName
        } else {
            Write-Host "Warning: Workspace ID or Pipeline Name not found for branch '$branchName'."
            exit 1
        }
    } catch {
        Write-Host "Error reading config file: $_"
        exit 1
    }
}

# Get pipeline ID by name from the workspace
function Get-PipelineId {
    param ($accessToken, $workspaceId, $pipelineName)

    $url = "$resourceUrl/v1/workspaces/$workspaceId/items"
    $headers = @{ 
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $pipeline = $response.value | Where-Object { $_.type -eq "DataPipeline" -and $_.displayName -eq $pipelineName }
        
        if ($pipeline) {
            Write-Host "Pipeline found: $($pipeline.displayName) with ID: $($pipeline.id)"
            return $pipeline.id
        } else {
            Write-Host "Error: Pipeline '$pipelineName' not found in workspace '$workspaceId'."
            exit 1
        }
    } catch {
        Write-Host "Error retrieving pipeline list: $_.Exception.Message"
        Write-Host "Full response (if any): $($_.Exception.Response | ConvertTo-Json -Depth 3)"
        exit 1
    }
}

# Run the data pipeline
function Run-DataPipeline {
    param ($accessToken, $workspaceId, $pipelineId)

    $url = "$resourceUrl/v1/workspaces/$workspaceId/items/$pipelineId/jobs/instances?jobType=Pipeline"
    $headers = @{ 
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    $body = @{
        executionData = @{}
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -OutVariable webResponse
        Write-Host "Pipeline run request sent successfully."
        Write-Host "Response body (if any): $($response | ConvertTo-Json -Depth 3)"

        $webResponseObj = $webResponse[0]
        if ($webResponseObj.Headers -and $webResponseObj.Headers["Location"]) {
            $jobId = $webResponseObj.Headers["Location"] -replace ".*/instances/", ""
            Write-Host "Job ID: $jobId"
            return $jobId
        } else {
            Write-Host "Warning: Job ID not found in response headers."
            return $null
        }
    } catch {
        Write-Host "Error running pipeline: $_.Exception.Message"
        Write-Host "Full response (if any): $($_.Exception.Response | ConvertTo-Json -Depth 3)"
        exit 1
    }
}

# Execution
$accessToken = Get-AccessToken
$branchName = Get-CurrentGitBranch
$workspaceId, $pipelineName = Get-IdsFromFile -branchName $branchName
$pipelineId = Get-PipelineId -accessToken $accessToken -workspaceId $workspaceId -pipelineName $pipelineName
$jobId = Run-DataPipeline -accessToken $accessToken -workspaceId $workspaceId -pipelineId $pipelineId

if ($jobId) {
    Write-Host "Pipeline started successfully with Job ID: $jobId"
} else {
    Write-Host "Warning: Job ID not returned, but pipeline may have started."
}