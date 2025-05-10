# Script: test_env.ps1
# Description: Tests the demo environment setup for Cursor AI linting demo
# Author: Claude

#Requires -Version 5.1

param(
    [switch]$Verbose = $false
)

function Write-Status {
    param(
        [string]$Component,
        [string]$Status,
        [string]$Details = ""
    )
    
    switch ($Status) {
        "OK" { $color = "Green" }
        "WARNING" { $color = "Yellow" }
        "ERROR" { $color = "Red" }
        default { $color = "White" }
    }
    
    Write-Host "$Component : " -NoNewline
    Write-Host $Status -ForegroundColor $color
    
    if ($Details -and $Verbose) {
        Write-Host "  $Details" -ForegroundColor Gray
    }
}

Clear-Host
Write-Host "Testing Cursor AI Linting Demo Environment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Define paths
$basePath = "/Users/adam/Library/CloudStorage/GoogleDrive-adbertram@gmail.com/My Drive/Adam the Automator/Courses/integrating-ai-agents-enterprise-systems"
$projectPath = Join-Path -Path $basePath -ChildPath "my-membership"
$servicePath = Join-Path -Path $projectPath -ChildPath "src/services/ApiService.js"
$envSetupPath = Join-Path -Path $basePath -ChildPath "env_setup/m2c1-Cursor AI for Linting"
$rollbackPath = Join-Path -Path $envSetupPath -ChildPath "rollback_data.json"
$rollbackScriptPath = Join-Path -Path $envSetupPath -ChildPath "rollback.ps1"

# Test 1: Check if Cursor is installed
$cursorPaths = @(
    "/Applications/Cursor.app",
    "$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe"
)

$cursorInstalled = $false
foreach ($path in $cursorPaths) {
    if (Test-Path $path) {
        $cursorInstalled = $true
        break
    }
}

if ($cursorInstalled) {
    Write-Status -Component "Cursor Installation" -Status "OK" -Details "Cursor is installed"
} else {
    Write-Status -Component "Cursor Installation" -Status "ERROR" -Details "Cursor is not installed. Download from https://cursor.sh/"
}

# Test 2: Check for project directory
if (Test-Path $projectPath) {
    Write-Status -Component "Project Directory" -Status "OK" -Details "Project directory exists at $projectPath"
} else {
    Write-Status -Component "Project Directory" -Status "ERROR" -Details "Project directory not found at $projectPath"
}

# Test 3: Check for ApiService.js with linting issues
if (Test-Path $servicePath) {
    $content = Get-Content -Path $servicePath -Raw
    
    # Check for expected linting issues
    $lintingIssues = @(
        "Missing semicolon",
        "camelCase violation",
        "Double quotes"
    )
    
    $allIssuesFound = $true
    foreach ($issue in $lintingIssues) {
        if ($content -notmatch [regex]::Escape($issue)) {
            $allIssuesFound = $false
            Write-Status -Component "ApiService.js Content" -Status "WARNING" -Details "Missing expected linting issue comment: $issue"
        }
    }
    
    if ($allIssuesFound) {
        Write-Status -Component "ApiService.js Content" -Status "OK" -Details "File contains expected linting issues"
    } else {
        Write-Status -Component "ApiService.js Content" -Status "WARNING" -Details "Some expected linting issues not found in comments"
    }
} else {
    Write-Status -Component "ApiService.js" -Status "ERROR" -Details "ApiService.js not found at $servicePath"
}

# Test 4: Check for rollback data
if (Test-Path $rollbackPath) {
    try {
        $rollbackData = Get-Content -Path $rollbackPath -Raw | ConvertFrom-Json
        if ($rollbackData.ApiServicePath -and $rollbackData.OriginalContent) {
            Write-Status -Component "Rollback Data" -Status "OK" -Details "Rollback data is available and valid"
        } else {
            Write-Status -Component "Rollback Data" -Status "WARNING" -Details "Rollback data may be incomplete"
        }
    } catch {
        Write-Status -Component "Rollback Data" -Status "ERROR" -Details "Rollback data is not valid JSON"
    }
} else {
    Write-Status -Component "Rollback Data" -Status "ERROR" -Details "Rollback data not found at $rollbackPath"
}

# Test 5: Check for rollback script
if (Test-Path $rollbackScriptPath) {
    Write-Status -Component "Rollback Script" -Status "OK" -Details "Rollback script is available"
} else {
    Write-Status -Component "Rollback Script" -Status "ERROR" -Details "Rollback script not found at $rollbackScriptPath"
}

# Test 6: Check for ESLint in project
$eslintConfigPath = Join-Path -Path $projectPath -ChildPath "eslint.config.js"
if (Test-Path $eslintConfigPath) {
    Write-Status -Component "ESLint Configuration" -Status "OK" -Details "ESLint configuration found"
} else {
    Write-Status -Component "ESLint Configuration" -Status "ERROR" -Details "ESLint configuration not found at $eslintConfigPath"
}

Write-Host ""
Write-Host "Environment test completed." -ForegroundColor Cyan
