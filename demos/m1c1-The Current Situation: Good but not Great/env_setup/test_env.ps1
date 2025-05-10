# Carved Rock Fitness Demo Test Script
# This script demonstrates the environment created by the setup script and simulates testing the AI agent solution

param(
    [string]$ProjectPath = "/Users/adam/Library/CloudStorage/GoogleDrive-adbertram@gmail.com/My Drive/Adam the Automator/Courses/integrating-ai-agents-enterprise-systems/my-membership",
    [switch]$Interactive = $false,
    [switch]$SkipCleanup = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to output colored status messages
function Write-Status {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor $Color
}

# Function to get confirmation in interactive mode
function Get-Confirmation {
    param([string]$Message, [switch]$Required)
    
    if (-not $Interactive -and -not $Required) {
        return $true
    }
    
    $confirmation = Read-Host "$Message (y/n)"
    return ($confirmation -eq 'y' -or $confirmation -eq 'Y')
}

# Function to check if the current directory is a git repository
function Test-GitRepository {
    param([string]$Path)
    
    $originalLocation = Get-Location
    try {
        Set-Location -Path $Path
        $gitStatus = git rev-parse --is-inside-work-tree 2>&1
        return ($gitStatus -eq "true")
    } catch {
        return $false
    } finally {
        Set-Location -Path $originalLocation
    }
}

# Function to check if GitHub CLI is installed
function Test-GitHubCLI {
    try {
        gh --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Function to verify GitHub CLI authentication
function Test-GitHubAuth {
    try {
        $status = gh auth status 2>&1
        if ($status -match "Logged in to github.com") {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

# Exit function with formatted message
function Exit-WithMessage {
    param(
        [string]$Message,
        [int]$ExitCode = 1
    )
    Write-Status $Message "Red"
    exit $ExitCode
}

# Main script execution
Write-Status "Starting Carved Rock Fitness Demo Test..." "Green"

# Verify prerequisites
Write-Status "Verifying prerequisites..." "Cyan"

# Check if the project path exists
if (-not (Test-Path -Path $ProjectPath)) {
    Exit-WithMessage "Project path does not exist: $ProjectPath"
}

# Check if it's a Git repository
if (-not (Test-GitRepository -Path $ProjectPath)) {
    Exit-WithMessage "Not a Git repository: $ProjectPath"
}

# Check if GitHub CLI is installed
if (-not (Test-GitHubCLI)) {
    Exit-WithMessage "GitHub CLI is not installed. Please install it first."
}

# Check if GitHub CLI is authenticated
if (-not (Test-GitHubAuth)) {
    Exit-WithMessage "GitHub CLI is not authenticated. Please run 'gh auth login' first."
}

try {

    # Navigate to the project directory
    Set-Location -Path $ProjectPath
    Write-Status "Working in directory: $ProjectPath" "Green"

    # Display current repository state
    Write-Status "Current repository state:" "Cyan"
    Write-Status "Current branch: $(git rev-parse --abbrev-ref HEAD)" "Yellow"

    # 1. Create a new branch for testing
    $branchName = "test-lint-workflow-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Status "Creating new branch: $branchName" "Cyan"
    git checkout -b $branchName

    if ($LASTEXITCODE -ne 0) {
        Exit-WithMessage "Failed to create new branch."
    }

    # 2. Create or modify a file with intentional ESLint errors
    $testFilePath = Join-Path -Path $ProjectPath -ChildPath "src/components/TestComponent.jsx"
    $parentDir = Split-Path -Parent $testFilePath
    if (-not (Test-Path -Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    Write-Status "Creating test file with ESLint errors: $testFilePath" "Cyan"
    $fileContent = @"
// This file contains intentional ESLint errors for testing
import React from 'react'

// Unused variable (will trigger no-unused-vars rule)
const unusedVar = 'This variable is never used';

// Console statement (often flagged in production code)
function TestComponent(props) {
    // Console statement (will trigger no-console rule)
    console.log('This is a test component');
    
    // Return JSX with props without validation (will trigger react/prop-types rule)
    return (
        <div>
            <h1>{props.title}</h1>
            <p>{props.description}</p>
        </div>
    )
}

export default TestComponent;
"@

    $fileContent | Out-File -FilePath $testFilePath -Encoding utf8

    # 3. Stage and commit the change
    Write-Status "Staging and committing changes..." "Cyan"
    git add -v $testFilePath
    git commit -v -m "Add test component with linting issues"

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to commit changes."
    }

    # 4. Push the branch to remote
    Write-Status "Pushing branch to remote..." "Cyan"
    git push -u origin $branchName

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push branch to remote."
    }

    # 5. Create a pull request
    Write-Status "Creating pull request..." "Cyan"
    $prUrl = gh pr create --title "Test: Component with linting issues" --body "This PR contains a component with intentional linting issues to test the automated workflow." --base main

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create pull request."
    }

    Write-Status "Pull request created: $prUrl" "Green"

    # Extract PR number and define expected issue title
    $prNumber = $prUrl.Split('/')[-1]
    $expectedIssueTitle = "ESLint Violations Found in PR #$prNumber"
    Write-Status "Expecting issue title: '$expectedIssueTitle'" "Yellow"

    # 6. Wait for GitHub Actions workflow to complete
    Write-Status "Waiting for GitHub Actions workflow to complete..." "Cyan"
    $workflowComplete = $false
    $maxAttempts = 30
    $attempts = 0
    $waitTimeSeconds = 15  # Increased wait time between checks

    while (-not $workflowComplete -and $attempts -lt $maxAttempts) {
        $attempts++
        Write-Status "Checking workflow status (attempt $attempts of $maxAttempts)..." "Yellow"
    
        $runStatus = gh run list --workflow=code-quality-check.yml --branch=$branchName --limit=1 --json "status,conclusion,databaseId,url"
        $runStatusObj = $runStatus | ConvertFrom-Json
    
        if ($runStatusObj.Count -eq 0) {
            Write-Status "No workflow runs found yet. Waiting $waitTimeSeconds seconds..." "Yellow"
            Start-Sleep -Seconds $waitTimeSeconds
            continue
        }
    
        $status = $runStatusObj[0].status
        $conclusion = $runStatusObj[0].conclusion
        $runId = $runStatusObj[0].databaseId
        $runUrl = $runStatusObj[0].url
    
        Write-Status "Workflow status: $status, conclusion: $conclusion" "Yellow"
        Write-Status "Workflow URL: $runUrl" "Yellow"
    
        if ($status -eq "completed") {
            $workflowComplete = $true
            Write-Status "Workflow run completed with conclusion: $conclusion" "Green"
        
            # For our test purposes, we'll consider any completion as success
            # The workflow might "fail" due to ESLint errors, but that's expected
            Write-Status "Note: The workflow might show as 'failure' if ESLint found issues, but that's expected behavior." "Yellow"
            Write-Status "What matters is whether it created GitHub issues for the linting errors." "Yellow"
        } else {
            Write-Status "Workflow still running. Waiting $waitTimeSeconds seconds..." "Yellow"
            Start-Sleep -Seconds $waitTimeSeconds
        }
    }

    if (-not $workflowComplete) {
        throw "Timed out waiting for workflow to complete."
    }

    # 7. Verify issue creation from workflow logs
    Write-Status "Verifying issue creation from workflow logs..." "Cyan"
    $issueFound = $false

    if ($runId) {
        Write-Status "Fetching logs for workflow run: $runId..." "Yellow"
        try {
            $logs = gh run view $runId --log

            if (-not [string]::IsNullOrWhiteSpace($logs)) {
                # Check logs for expected issue title using the specific PR number
                if ($logs -like "*$expectedIssueTitle*") {
                    Write-Status "Expected issue title found in logs: '$expectedIssueTitle'" "White"

                    # Search for the specific open issue by title
                    Write-Status "Searching for open issue with title: '$expectedIssueTitle'..." "Yellow"
                    try {
                        # Use -S for searching by title/body, ensure state is open
                        $foundIssues = gh issue list -S "$expectedIssueTitle" --state open --json "number,title,url" --limit 1 | ConvertFrom-Json
                        
                        # Check if foundIssues is not null and not empty
                        if ($null -ne $foundIssues -and $foundIssues.Count -eq 1 -and $foundIssues[0].title -eq $expectedIssueTitle) {
                            $issueFound = $true
                            $foundIssueUrl = $foundIssues[0].url
                            Write-Status "Successfully found matching open issue: $foundIssueUrl" "Green"
                        } else {
                            Write-Status "No matching open issue found with the exact title." "Red"
                            # Optional: Output the search results if any were returned but didn't match
                            if ($null -ne $foundIssues -and $foundIssues.Count -gt 0) {
                                Write-Host "Search returned: $($foundIssues | ConvertTo-Json -Depth 2)"
                            }
                        }
                    } catch {
                        Write-Status "Error searching for issue: $_" "Red"
                        Write-Error "Error details during issue search: $($_.Exception.Message)" # Added specific error
                    }
                } else {
                    Write-Status "Could not find expected issue title in workflow logs." "Red"
                }
            } else {
                 Write-Status "Workflow logs were empty or whitespace." "Red"
            }
        } catch {
            Write-Status "Error fetching workflow logs: $_" "Red"
            Write-Error "Error details during log fetch: $($_.Exception.Message)" # Added specific error
        }
    } else {
        Write-Status "Workflow Run ID is not available. Cannot fetch logs." "Red"
    }

    # Update summary variables based on verification
    $issuesCreatedCount = if ($issueFound) { 1 } else { 0 }
    # We can't easily get the total error count from logs, so set to 1 if issue found, else 0
    $totalLintIssues = if ($issueFound) { 1 } else { 0 }

    # Test Summary Section (original position adjusted)
    Write-Status "
Test Summary:" "Magenta"
    Write-Status "1. Created branch: $branchName" "White"
    Write-Status "2. Added file with ESLint errors: $testFilePath" "White"
    Write-Status "3. Created pull request: $prUrl" "White"
    $statusString = if ($workflowComplete) { "Completed" } else { "Timed out" }
    $conclusionString = if ($conclusion) { $conclusion } else { "Unknown" }
    Write-Status "4. GitHub Actions workflow status: $statusString" "White"
    Write-Status "5. Workflow conclusion: $conclusionString" "White"
    Write-Status "6. ESLint summary issue created: $($issuesCreatedCount)" "White"
    Write-Status "7. Total recent linting issues (verification focus): $($totalLintIssues)" "White"

} catch {
    Write-Error "Error during test execution: $($_.Exception.Message)"
    # Ensure summary variables exist for the finally block
    $branchName = if ($branchName) { $branchName } else { "N/A" }
    $testFilePath = if ($testFilePath) { $testFilePath } else { "N/A" }
    $prUrl = if ($prUrl) { $prUrl } else { "N/A" }
    $statusString = if ($workflowComplete) { "Completed" } else { "Timed out" }
    $conclusionString = if ($conclusion) { $conclusion } else { "Unknown" }
    $issuesCreatedCount = if ($issuesCreatedCount) { $issuesCreatedCount } else { 0 }
    $totalLintIssues = if ($totalLintIssues) { $totalLintIssues } else { 0 }

    Write-Status "
Test Summary (Partial due to error):" "Magenta"
    Write-Status "1. Created branch: $branchName" "White"
    Write-Status "2. Added file with ESLint errors: $testFilePath" "White"
    Write-Status "3. Created pull request: $prUrl" "White"
    Write-Status "4. GitHub Actions workflow status: $statusString" "White"
    Write-Status "5. Workflow conclusion: $conclusionString" "White"
    Write-Status "6. ESLint issues created for test file: $($issuesCreatedCount)" "White"
    Write-Status "7. Total recent linting issues: $($totalLintIssues)" "White"
} finally {
    # Cleanup
    Write-Status "Cleaning up test resources..." "Cyan"
    if ($prUrl -and $prUrl -ne "N/A") {
        try {
            $prNumber = $prUrl.Split('/')[-1]
            gh pr close $prNumber --delete-branch
            Write-Status "Closed PR #$prNumber and deleted remote branch $branchName" "Green"
        } catch {
            Write-Warning "Failed to close PR or delete remote branch: $($_.Exception.Message)"
        }
    }
    
    # Switch back to main branch and delete local test branch
    git checkout main
    if (git branch --list $branchName) {
        git branch -D $branchName
    }
    # Try deleting remote branch if PR close failed
    if ($LASTEXITCODE -ne 0 -and $branchName -ne "N/A") {
        Write-Warning "Attempting direct remote branch deletion for $branchName"
        git push origin --delete $branchName
    }

    Write-Status "Cleanup complete" "Green"
    Write-Status "
Test environment demonstration complete!" "Magenta"
}