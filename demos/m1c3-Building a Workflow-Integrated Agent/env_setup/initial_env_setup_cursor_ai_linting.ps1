# Script: initial_env_setup_cursor_ai_linting.ps1
# Description: Prepares a demo environment for showcasing Cursor AI's capabilities to detect and fix linting issues
# Author: Claude

#Requires -Version 5.1

# Define parameters with default values
param(
    [switch]$Interactive = $false,
    [string]$LogPath = "./cursor_ai_linting_setup.log"
)

# Common functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Output to console with color coding
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
    
    # Write to log file
    Add-Content -Path $LogPath -Value $logMessage
}

function Confirm-Action {
    param(
        [string]$Message,
        [switch]$Default = $true
    )
    
    if (-not $Interactive) {
        return $true
    }
    
    $choices = "&Yes", "&No"
    $defaultChoice = 0
    if (-not $Default) {
        $defaultChoice = 1
    }
    
    $decision = $Host.UI.PromptForChoice("Confirmation Required", $Message, $choices, $defaultChoice)
    return $decision -eq 0
}

function Restore-Original {
    param(
        [string]$Path,
        [string]$OriginalContent
    )
    Set-Content -Path $Path -Value $OriginalContent
    Write-Log "Restored original content for $Path" -Level "INFO"
}

# Helper function to check if Cursor is installed
function Test-CursorInstalled {
    $cursorPaths = @(
        "/Applications/Cursor.app",
        "$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe"
    )
    
    foreach ($path in $cursorPaths) {
        if (Test-Path $path) {
            return $true
        }
    }
    return $false
}

# Main script execution starts here
Clear-Host

# Create log file
$null = New-Item -Path $LogPath -ItemType File -Force

# Print banner and setup summary
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host "           Cursor AI for Linting Demo Setup" -ForegroundColor Magenta
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host ""

Write-Log "Starting demo environment setup..."

# Define paths
$basePath = "/Users/adam/Library/CloudStorage/GoogleDrive-adbertram@gmail.com/My Drive/Adam the Automator/Courses/integrating-ai-agents-enterprise-systems"
$projectPath = Join-Path -Path $basePath -ChildPath "my-membership"
$servicePath = Join-Path -Path $projectPath -ChildPath "src/services/ApiService.js"
$envSetupPath = Join-Path -Path $basePath -ChildPath "env_setup/m2c1-Cursor AI for Linting"
$rollbackPath = Join-Path -Path $envSetupPath -ChildPath "rollback_data.json"

# Verify project path exists
if (-not (Test-Path $projectPath)) {
    Write-Log "Project path $projectPath does not exist!" -Level "ERROR"
    exit 1
}

# Summary of changes to be made
$setupSteps = @(
    "1. Verify Cursor is installed",
    "2. Backup current ApiService.js",
    "3. Inject linting issues into ApiService.js",
    "4. Create rollback data for easy restoration"
)

Write-Host "This script will perform the following actions:" -ForegroundColor Yellow
$setupSteps | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
Write-Host ""

if ($Interactive) {
    $proceed = Confirm-Action -Message "Do you want to proceed with the setup?"
    if (-not $proceed) {
        Write-Log "Setup cancelled by user" -Level "WARNING"
        exit 0
    }
}

# Step 1: Verify Cursor is installed
Write-Log "Checking if Cursor is installed..."
$cursorInstalled = Test-CursorInstalled

if (-not $cursorInstalled) {
    Write-Log "Cursor is not installed! Please install Cursor from https://cursor.sh/" -Level "ERROR"
    if (Confirm-Action -Message "Cursor is not installed. Would you like to open the Cursor download page?") {
        Start-Process "https://cursor.sh/"
        Write-Log "Opened Cursor download page in browser" -Level "INFO"
    }
    exit 1
}
else {
    Write-Log "Cursor is installed" -Level "SUCCESS"
}

# Step 2: Backup current ApiService.js
Write-Log "Backing up current ApiService.js..."

if (-not (Test-Path $servicePath)) {
    Write-Log "ApiService.js not found at $servicePath!" -Level "ERROR"
    exit 1
}

$originalContent = Get-Content -Path $servicePath -Raw
$backupPath = Join-Path -Path $envSetupPath -ChildPath "ApiService.js.backup"
Set-Content -Path $backupPath -Value $originalContent
Write-Log "Backup created at $backupPath" -Level "SUCCESS"

# Step 3: Inject linting issues into ApiService.js
Write-Log "Injecting linting issues into ApiService.js..."

# Content with intentional linting issues
$contentWithLintingIssues = @'
// Service for API operations
const API_BASE_URL = "https://api.carvedrockfitness.com/v1"  // Missing semicolon and using double quotes

// Function with line length and indentation issues
export const fetchMembershipPlans = async () => {
    const response = await fetch(`${API_BASE_URL}/membership/plans`)  // Missing semicolon
    
    if (!response.ok) {
        throw new Error(`Failed to fetch membership plans: ${response.status}`)  // Missing semicolon
    }
    
    return response.json();
}

// Function with camelCase violations
export const fetch_user_profile = async (user_id) => {  // camelCase violation
    const response = await fetch(`${API_BASE_URL}/users/${user_id}/profile`);
    return response.json();
}

// Function with multiple issues
export const processPayment = async (payment_details) => {  // camelCase violation
    console.log("Processing payment", payment_details);  // Console warning and double quotes
    
    const response = await fetch(`${API_BASE_URL}/payments/process`, {
                method: "POST",  // Wrong indentation and double quotes
                headers: {
                    "Content-Type": "application/json"  // Double quotes
                },
                body: JSON.stringify(payment_details)
            });
    
    return response.json();
}

// Unused function
export const unused_function = () => {  // camelCase violation
    const unused_var = "This is not used";  // camelCase violation and unused variable
    return true;
}
'@

if (Confirm-Action -Message "Do you want to update ApiService.js with linting issues for the demo?") {
    Set-Content -Path $servicePath -Value $contentWithLintingIssues
    Write-Log "Updated ApiService.js with linting issues" -Level "SUCCESS"
}
else {
    Write-Log "Skipped updating ApiService.js" -Level "WARNING"
}

# Step 4: Create rollback data for easy restoration
Write-Log "Creating rollback data..."

$rollbackData = @{
    "ApiServicePath" = $servicePath
    "OriginalContent" = $originalContent
    "Timestamp" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$rollbackJson = $rollbackData | ConvertTo-Json
Set-Content -Path $rollbackPath -Value $rollbackJson
Write-Log "Rollback data created at $rollbackPath" -Level "SUCCESS"

# Create a rollback script
$rollbackScriptPath = Join-Path -Path $envSetupPath -ChildPath "rollback.ps1"
$rollbackScriptContent = @"
# Script: rollback.ps1
# Description: Restores the demo environment to its pre-demo state
# Author: Claude

param(
    [switch]`$Force = `$false
)

`$rollbackPath = "$rollbackPath"
`$rollbackData = Get-Content -Path `$rollbackPath -Raw | ConvertFrom-Json

if (-not `$Force) {
    `$confirmation = Read-Host "Are you sure you want to rollback changes? (yes/no)"
    if (`$confirmation -ne "yes") {
        Write-Host "Rollback cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Rolling back changes..." -ForegroundColor Cyan
Set-Content -Path `$rollbackData.ApiServicePath -Value `$rollbackData.OriginalContent
Write-Host "Rollback completed successfully. ApiService.js has been restored." -ForegroundColor Green
"@

Set-Content -Path $rollbackScriptPath -Value $rollbackScriptContent
Write-Log "Created rollback script at $rollbackScriptPath" -Level "SUCCESS"

# Final message
Write-Host ""
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host "           Demo Setup Completed Successfully" -ForegroundColor Magenta
Write-Host "=============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "1. Start the Cursor editor" -ForegroundColor Green
Write-Host "2. Open the file: $servicePath" -ForegroundColor Green
Write-Host "3. Follow the demo steps in the demo_scenario.md file" -ForegroundColor Green
Write-Host ""
Write-Host "To rollback changes after the demo, run:" -ForegroundColor Yellow
Write-Host "  & '$rollbackScriptPath'" -ForegroundColor Yellow
Write-Host ""

Write-Log "Setup completed successfully" -Level "SUCCESS"
