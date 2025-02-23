# Parameters
$configPath = "config.json"
$semantic_model_path = "fabric/semantic_model_001.SemanticModel/definition/expressions.tmdl"

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

$branch = Get-CurrentGitBranch

# Convert Config JSON
$data = Get-Content $configPath -Raw | ConvertFrom-Json

# Get replacements
$new_sql_connection_string = $data.$branch.sql_connection_string
$new_sql_lakehouse_id            = $data.$branch.sql_lakehouse_id

# Transform SQL Connection String (Uppercase only first part)
$pattern = '^(.*?)\.datawarehouse\.fabric\.microsoft\.com$'
if ($new_sql_connection_string -match $pattern) {
    $upperPart = $matches[1].ToUpper()
    $new_sql_connection_string = "$upperPart.datawarehouse.fabric.microsoft.com"
}

# Read all semantic_model_path
$content = [System.IO.File]::ReadAllText($semantic_model_path)

# Pattern of replacements
$pattern = 'Sql\.Database\("([^"]+)",\s*"([^"]+)"\)'
$replacement = "Sql.Database(`"$new_sql_connection_string`", `"$new_sql_lakehouse_id`")"

# Execute the replacements
$newContent = [regex]::Replace($content, $pattern, $replacement)

# Write back
[System.IO.File]::WriteAllText($semantic_model_path, $newContent)

