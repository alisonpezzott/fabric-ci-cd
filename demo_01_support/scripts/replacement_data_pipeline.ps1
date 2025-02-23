# Parameters
$pipelinePath = "fabric\pipeline_001.DataPipeline\pipeline-content.json"
$configPath = "config.json"

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

# Load gateway_connection_id from config
function Get-GatewayConnectionId {
    param ($branchName)

    if (-not (Test-Path $configPath)) {
        Write-Host "Config file not found: $configPath"
        return $null
    }

    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        $gatewayConnectionId = $config.$branchName.gateway_connection_id

        if (-not $gatewayConnectionId) {
            Write-Host "gateway_connection_id not found for branch '$branchName' in config.json. Using default."
            return "6a607f35-54e0-491c-89be-0dff4a47ab00"
        }
        return $gatewayConnectionId
    } catch {
        Write-Host "Error reading config file: $_"
        return $null
    }
}

# Get branch and gateway_connection_id
$branchName = Get-CurrentGitBranch
$gatewayConnectionId = Get-GatewayConnectionId -branchName $branchName

if (-not $gatewayConnectionId) {
    Write-Host "Failed to retrieve gateway_connection_id. Exiting."
    exit 1
}

# Read pipeline JSON
try {
    $pipelineContent = Get-Content -Path $pipelinePath -Raw | ConvertFrom-Json -Depth 32
} catch {
    Write-Host "Error reading pipeline JSON: $_"
    exit 1
}

# Replace connection in externalReferences
$updated = $false

foreach ($activity in $pipelineContent.properties.activities) {
    if ($activity.typeProperties.activities) {
        foreach ($subActivity in $activity.typeProperties.activities) {
            if ($subActivity.typeProperties.source.datasetSettings.externalReferences.connection) {
                $oldConnection = $subActivity.typeProperties.source.datasetSettings.externalReferences.connection
                $subActivity.typeProperties.source.datasetSettings.externalReferences.connection = $gatewayConnectionId
                $updated = $true
            }
        }
    }
}

# Save the updated JSON if changes were made
if ($updated) {
    try {
        # Convert the object to JSON with high depth and preserve formatting
        $newJson = $pipelineContent | ConvertTo-Json -Depth 32 | Out-String

        # Remove trailing blank lines
        $newJson = $newJson -replace "`r?`n+$", ""

        # Convert CRLF to LF for consistency
        $newJson = $newJson -replace "`r`n", "`n"

        # Save JSON with proper formatting
        [System.IO.File]::WriteAllText($pipelinePath, $newJson)

        Write-Host "Replace completed."
    } catch {
        Write-Host "Error saving file $($pipelinePath): $_"
        exit 1
    }
}
