# Parameters
$notebookPath = "fabric\notebook_001.Notebook\notebook-content.py"
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

# Load workspace_name from config
function Get-WorkspaceNameFromFile {
    param ($branchName)

    if (-not (Test-Path $configPath)) {
        Write-Host "Config file not found: $configPath"
        return $null
    }

    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        $workspaceName = $config.$branchName.workspace_name

        if (-not $workspaceName) {
            Write-Host "Workspace name not found for branch '$branchName' in config.json"
            return $null
        }
        return $workspaceName
    } catch {
        Write-Host "Error reading config file: $_"
        return $null
    }
}

# Get branch and workspace name
$branchName = Get-CurrentGitBranch
$workspaceName = Get-WorkspaceNameFromFile -branchName $branchName

if (-not $workspaceName) {
    Write-Host "Failed to retrieve workspace name. Exiting."
    exit 1
}

# Read notebook
try {
    $notebookContent = Get-Content -Path $notebookPath -Raw
} catch {
    Write-Host "Error reading notebook: $_"
    exit 1
}

# Replace the values
$pattern = 'workspace_name\s*=\s*"[^"]*"'
$newWorkspaceLine = "workspace_name = ""$workspaceName"""

if ($notebookContent -match $pattern) {
    $updatedContent = $notebookContent -replace $pattern, $newWorkspaceLine
    try {
        $updatedContent | Out-File -FilePath $notebookPath -Encoding utf8 -NoNewline
        Write-Host "Replace done successfully! New value: $workspaceName"
    } catch {
        Write-Host "Error saving file $($notebookPath): $_"
        exit 1
    }
} else {
    Write-Host "Warning: No line matching 'workspace_name = \"value\"' was found in the file."
}
