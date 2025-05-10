# Carved Rock Fitness Demo Setup Script
# This script configures the environment for demonstrating linting workflow problems
# Works with the existing project at /Users/adam/Library/CloudStorage/GoogleDrive-adbertram@gmail.com/My Drive/Adam the Automator/Courses/integrating-ai-agents-enterprise-systems/my-membership

# Parameters
param(
    [string]$ProjectPath = "/Users/adam/Library/CloudStorage/GoogleDrive-adbertram@gmail.com/My Drive/Adam the Automator/Courses/integrating-ai-agents-enterprise-systems/my-membership",
    [string]$AssigneeEmail = "adbertram@gmail.com",
    [switch]$Force,
    [switch]$Interactive,
    [switch]$Rollback
)

# Set error action preference
$ErrorActionPreference = "Stop"

$currentPath = Get-Location

# Initialize tracker for created resources
$script:CreatedResources = @{
    Files = @()
    Branches = @()
    Issues = @()
    PRs = @()
}

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

# Function to create a backup of the repository
function Backup-Repository {
    param([string]$Path)
    
    Write-Status "Creating backup of repository state..." "Cyan"
    
    # Create backup directory if it doesn't exist
    $backupDir = Join-Path -Path $Path -ChildPath ".demo-backup"
    if (-not (Test-Path -Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    
    # Verify this is a git repository
    if (-not (Test-GitRepository -Path $Path)) {
        Write-Status "Not a Git repository. Cannot create backup." "Red"
        return $false
    }
    
    # Save current branch information
    $currentBranch = git rev-parse --abbrev-ref HEAD
    $currentBranch | Out-File -FilePath (Join-Path -Path $backupDir -ChildPath "current-branch.txt") -Encoding utf8
    
    # Create backup commit to easily revert changes
    if (Get-Confirmation "Create backup commit to track current state?" -Required) {
        git add .
        git commit -m "BACKUP: State before demo setup script - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Status "Created backup commit" "Green"
    }
    
    # Save list of current branches
    git branch | Out-File -FilePath (Join-Path -Path $backupDir -ChildPath "branches.txt") -Encoding utf8
    
    # Save list of current issues (if any)
    try {
        $issues = gh issue list --limit 100 --json number,title,url
        $issues | Out-File -FilePath (Join-Path -Path $backupDir -ChildPath "issues.json") -Encoding utf8
    } catch {
        Write-Status "Could not backup current issues: $_" "Yellow"
    }
    
    # Save list of current PRs (if any)
    try {
        $prs = gh pr list --limit 100 --json number,title,url
        $prs | Out-File -FilePath (Join-Path -Path $backupDir -ChildPath "prs.json") -Encoding utf8
    } catch {
        Write-Status "Could not backup current PRs: $_" "Yellow"
    }
    
    Write-Status "Repository backup complete" "Green"
    return $true
}

# Function to restore environment
function Restore-Environment {
    param([string]$Path)
    
    Write-Status "Restoring environment..." "Cyan"
    Set-Location -Path $Path
    
    # Check if we're in a Git repository
    if (-not (Test-GitRepository -Path $Path)) {
        Write-Status "Not a Git repository. Cannot restore Git-related changes." "Red"
        return $false
    }
    
    # Look for resource tracking file first
    $resourceTrackingPath = Join-Path -Path $Path -ChildPath ".demo-resources.json"
    if (Test-Path -Path $resourceTrackingPath) {
        Write-Status "Found resource tracking file. Loading resources to clean up..." "Green"
        try {
            $script:CreatedResources = Get-Content -Path $resourceTrackingPath -Raw | ConvertFrom-Json
            
            # Convert properties to arrays if they're not already
            if ($null -eq $script:CreatedResources.Files) { $script:CreatedResources.Files = @() }
            if ($null -eq $script:CreatedResources.Branches) { $script:CreatedResources.Branches = @() }
            if ($null -eq $script:CreatedResources.Issues) { $script:CreatedResources.Issues = @() }
            if ($null -eq $script:CreatedResources.PRs) { $script:CreatedResources.PRs = @() }
            
            # If properties are not arrays, convert them
            if ($script:CreatedResources.Files -isnot [Array]) { $script:CreatedResources.Files = @($script:CreatedResources.Files) }
            if ($script:CreatedResources.Branches -isnot [Array]) { $script:CreatedResources.Branches = @($script:CreatedResources.Branches) }
            if ($script:CreatedResources.Issues -isnot [Array]) { $script:CreatedResources.Issues = @($script:CreatedResources.Issues) }
            if ($script:CreatedResources.PRs -isnot [Array]) { $script:CreatedResources.PRs = @($script:CreatedResources.PRs) }
        } catch {
            Write-Status "Error loading resource tracking file: $_" "Red"
            $script:CreatedResources = @{
                Files = @()
                Branches = @()
                Issues = @()
                PRs = @()
            }
        }
    } else {
        Write-Status "No resource tracking file found. Will try to restore based on Git history." "Yellow"
        
        # Try to find issues with [LINT] prefix
        Write-Status "Searching for linting issues to close..." "Cyan"
        try {
            $lintIssues = gh issue list --search "[LINT]" --json number,title,url --limit 100
            if ($lintIssues) {
                $lintIssuesObj = $lintIssues | ConvertFrom-Json
                if ($lintIssuesObj.Count -gt 0) {
                    Write-Status "Found $($lintIssuesObj.Count) linting issues" "Green"
                    $script:CreatedResources.Issues = $lintIssuesObj.url
                } else {
                    Write-Status "No linting issues found" "Yellow"
                }
            }
        } catch {
            Write-Status "Error searching for linting issues: $_" "Red"
        }
    }
    
    # Check for backup directory (optional)
    $backupDir = Join-Path -Path $Path -ChildPath ".demo-backup"
    $hasBackupDir = Test-Path -Path $backupDir
    
    # Ask if user wants to delete created issues
    if ($script:CreatedResources.Issues.Count -gt 0 -and (Get-Confirmation "Do you want to close all $($script:CreatedResources.Issues.Count) issues created by this script?")) {
        foreach ($issueUrl in $script:CreatedResources.Issues) {
            try {
                $issueNumber = ($issueUrl -split "/")[-1]
                Write-Status "Closing issue #$issueNumber..." "Yellow"
                gh issue close $issueNumber
            } catch {
                Write-Status "Failed to close issue: $_" "Red"
            }
        }
    } else {
        # If no issues were found in the tracking file, try to find and close all [LINT] issues
        if ($script:CreatedResources.Issues.Count -eq 0 -and (Get-Confirmation "No tracked issues found. Do you want to search for and close all [LINT] issues?")) {
            try {
                Write-Status "Searching for linting issues..." "Cyan"
                $lintIssues = gh issue list --search "[LINT]" --json number,title --limit 100 | ConvertFrom-Json
                
                if ($lintIssues.Count -gt 0) {
                    Write-Status "Found $($lintIssues.Count) linting issues to close" "Green"
                    foreach ($issue in $lintIssues) {
                        Write-Status "Closing issue #$($issue.number): $($issue.title)" "Yellow"
                        gh issue close $issue.number
                    }
                } else {
                    Write-Status "No linting issues found" "Yellow"
                }
            } catch {
                Write-Status "Error closing linting issues: $_" "Red"
            }
        } else {
            Write-Status "No issues to close or closing skipped" "Yellow"
        }
    }
    
    # Ask if user wants to delete created PRs
    if ($script:CreatedResources.PRs.Count -gt 0 -and (Get-Confirmation "Do you want to close all $($script:CreatedResources.PRs.Count) pull requests created by this script?")) {
        foreach ($prUrl in $script:CreatedResources.PRs) {
            try {
                $prNumber = ($prUrl -split "/")[-1]
                Write-Status "Closing PR #$prNumber..." "Yellow"
                gh pr close $prNumber
            } catch {
                Write-Status "Failed to close PR: $_" "Red"
            }
        }
    } else {
        Write-Status "No PRs to delete or deletion skipped" "Yellow"
    }
    
    # Ask if user wants to delete created branches
    if ($script:CreatedResources.Branches.Count -gt 0 -and (Get-Confirmation "Do you want to delete all $($script:CreatedResources.Branches.Count) branches created by this script?")) {
        # First get back to main branch
        git checkout main
        
        foreach ($branch in $script:CreatedResources.Branches) {
            try {
                Write-Status "Deleting branch $branch..." "Yellow"
                git branch -D $branch
                git push origin --delete $branch
            } catch {
                Write-Status "Failed to delete branch $branch : $_" "Red"
            }
        }
    } else {
        Write-Status "No branches to delete or deletion skipped" "Yellow"
    }
    
    # Ask if user wants to delete created files
    if ($script:CreatedResources.Files.Count -gt 0 -and (Get-Confirmation "Do you want to delete all $($script:CreatedResources.Files.Count) files created by this script?")) {
        foreach ($file in $script:CreatedResources.Files) {
            if (Test-Path $file) {
                Write-Status "Deleting file $file..." "Yellow"
                Remove-Item -Path $file -Force
            }
        }
    } else {
        Write-Status "No files to delete or deletion skipped" "Yellow"
    }
    
    # Return to original branch if backup directory exists
    if ($hasBackupDir) {
        $originalBranchFile = Join-Path -Path $backupDir -ChildPath "current-branch.txt"
        if (Test-Path $originalBranchFile) {
            $originalBranch = Get-Content $originalBranchFile
            git checkout $originalBranch
            Write-Status "Returned to original branch: $originalBranch" "Green"
        }
    }
    
    # Find and revert the demo setup commit
    if (Get-Confirmation "Do you want to revert the demo setup commit?") {
        try {
            # Find the setup commit
            $setupCommit = git log --grep="Add demo files for linting workflow demonstration" --format="%H" -n 1
            
            if ($setupCommit) {
                Write-Status "Found demo setup commit: $setupCommit" "Green"
                
                if (Get-Confirmation "Revert this commit?") {
                    git revert $setupCommit --no-edit
                    Write-Status "Reverted demo setup commit" "Green"
                    
                    if (Get-Confirmation "Push this revert to origin?") {
                        git push origin HEAD
                        Write-Status "Pushed revert to origin" "Green"
                    }
                }
            } else {
                Write-Status "No demo setup commit found" "Yellow"
                
                # Option to hard reset to a specific commit
                if (Get-Confirmation "Do you want to reset to a specific commit?") {
                    $commitHash = Read-Host "Enter the commit hash to reset to"
                    if (-not [string]::IsNullOrWhiteSpace($commitHash)) {
                        Write-Status "Resetting to commit: $commitHash" "Yellow"
                        git reset --hard $commitHash
                        
                        if (Get-Confirmation "Push this reset to origin? This is destructive and cannot be undone!") {
                            git push --force origin HEAD
                            Write-Status "Forced push to origin complete" "Green"
                        }
                    }
                }
            }
        } catch {
            Write-Status "Failed to revert/reset repository: $_" "Red"
        }
    }
    
    # Clean up resource tracking file
    if (Test-Path -Path $resourceTrackingPath) {
        if (Get-Confirmation "Delete resource tracking file?") {
            Remove-Item -Path $resourceTrackingPath -Force
            Write-Status "Deleted resource tracking file" "Green"
        }
    }
    
    # Clean up backup directory if it exists
    if ($hasBackupDir) {
        if (Get-Confirmation "Delete backup directory?") {
            Remove-Item -Path $backupDir -Recurse -Force
            Write-Status "Deleted backup directory" "Green"
        }
    }
    
    Write-Status "Restore complete" "Green"
    return $true
}

# Register resources for restore
function Register-Resource {
    param(
        [string]$Type,
        [string]$Resource
    )
    
    switch ($Type) {
        "File" { $script:CreatedResources.Files += $Resource }
        "Branch" { $script:CreatedResources.Branches += $Resource }
        "Issue" { $script:CreatedResources.Issues += $Resource }
        "PR" { $script:CreatedResources.PRs += $Resource }
    }
}


try {
    # Handle restore if requested
    if ($Rollback) {
        if (Restore-Environment -Path $ProjectPath) {
            Write-Status "Restore completed successfully!" "Green"
            exit 0
        } else {
            Write-Status "Restore failed or was incomplete" "Yellow"
            exit 1
        }
    }
    
    # Check if project directory exists
    if (-not (Test-Path -Path $ProjectPath)) {
        Write-Status "Project directory not found: $ProjectPath" "Red"
        exit 1
    }
    
    # Create a backup of the current state for restore capability
    if (Get-Confirmation "Create a backup of the current repository state?" -Required) {
        Backup-Repository -Path $ProjectPath
    }
    
    # Display summary of changes to be made
    Write-Status "SUMMARY OF ACTIONS" "Green"
    Write-Status "===================" "Green"
    Write-Status "This script will make the following changes:" "White"
    Write-Status "1. Create/update GitHub Actions workflow file: .github/workflows/code-quality-check.yml" "White"
    Write-Status "2. Create the following files with intentional linting issues:" "White"
    Write-Status "   - src/components/UserProfile.jsx (camelCase violations, unused variables)" "White"
    Write-Status "   - src/components/MembershipCard.jsx (quote style, indentation issues)" "White"
    Write-Status "   - src/components/WorkoutCard.jsx (line length issues, missing semicolons)" "White"
    Write-Status "   - src/features/FeatureClass.jsx (prop-types issues, unused state)" "White"
    Write-Status "   - src/services/ApiService.js (various linting issues)" "White"
    Write-Status "3. Create DEMO-README.md with explanation of the setup" "White"
    Write-Status "4. Create feature branches and pull requests for fixes" "White"
    Write-Status "===================" "Green"
    
    # Prompt for confirmation unless -Force is used
    if (-not $Force) {
        $confirmation = Read-Host "Do you want to proceed with these changes? (y/n)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Status "Operation cancelled by user." "Yellow"
            exit 0
        }
    }
    
    # Navigate to the project directory
    Set-Location -Path $ProjectPath
    Write-Status "Changed directory to: $ProjectPath"
    
    # Check if the current directory is a Git repository
    if (-not (Test-GitRepository -Path $ProjectPath)) {
        Write-Status "This script must be run in a Git repository. Please navigate to a Git repository and try again." "Red"
        exit 1
    }
    
    # Check required dependencies and settings
    if (Get-Confirmation "Check GitHub CLI and authentication?" -Required) {
        Write-Status "Checking GitHub CLI..." "Cyan"
        $ghCliInstalled = Test-GitHubCLI
        
        if (-not $ghCliInstalled) {
            Exit-WithMessage "ERROR: GitHub CLI is not installed! Please install GitHub CLI from https://cli.github.com/ and run this script again."
        }
        
        Write-Status "GitHub CLI is installed!" "Green"
        $ghAuthenticated = Test-GitHubAuth
        
        if (-not $ghAuthenticated) {
            Write-Status "ERROR: GitHub CLI is not authenticated!" "Red"
            Write-Status "Please run 'gh auth login' and try again." "Red"
            
            $authNow = Read-Host "Do you want to authenticate now? (y/n)"
            if ($authNow -eq 'y' -or $authNow -eq 'Y') {
                gh auth login
                $ghAuthenticated = Test-GitHubAuth
                
                if (-not $ghAuthenticated) {
                    Exit-WithMessage "Authentication failed. Please authenticate manually and run this script again."
                }
            } else {
                exit 1
            }
        }
        
        Write-Status "GitHub CLI is authenticated!" "Green"
    }
    
    # Create the technical-debt label if it doesn't exist
    function New-TechnicalDebtLabel {
        Write-Status "Checking if 'technical-debt' label exists..." "Cyan"
        
        try {
            $labelExists = gh label list | Select-String -Pattern "technical-debt" -Quiet
            
            if (-not $labelExists) {
                Write-Status "Creating 'technical-debt' label..." "Yellow"
                gh label create "technical-debt" --color "#ff0000" --description "Issues related to code quality and technical debt"
                Write-Status "Created 'technical-debt' label" "Green"
            } else {
                Write-Status "'technical-debt' label already exists" "Green"
            }
            return $true
        } catch {
            Write-Status "Error creating 'technical-debt' label: $_" "Red"
            if ($Interactive) {
                $continue = Read-Host "Continue with script execution? (y/n)"
                if ($continue -ne 'y' -and $continue -ne 'Y') {
                    Write-Status "Script execution stopped by user." "Yellow"
                    exit 0
                }
            }
            return $false
        }
    }
    
    # Create GitHub Actions workflow for code quality
    Write-Status "Creating GitHub Actions workflow for code quality checks..."
    $workflowDir = Join-Path -Path $ProjectPath -ChildPath ".github/workflows"
    if (-not (Test-Path -Path $workflowDir)) {
        New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null
        Write-Status "Created directory: $workflowDir" "Green"
    }
    
    $workflowPath = Join-Path -Path $workflowDir -ChildPath "code-quality-check.yml"
    $workflowContent = @"
    name: Code Quality Check
    
    on:
      pull_request:
        types: [opened, synchronize, reopened]
        branches: [ main, develop ]
    
    jobs:
      lint:
        name: ESLint Check
        runs-on: ubuntu-latest
    
        steps:
          - uses: actions/checkout@v3
          
          - name: Setup Node.js
            uses: actions/setup-node@v3
            with:
              node-version: '18'
              
          - name: Install dependencies
            run: npm ci
            
          - name: Run ESLint
            id: eslint
            run: |
              RESULTS=`$(npx eslint --format json src/)
              echo "ESLINT_RESULTS=`$RESULTS" >> `$GITHUB_ENV
              
          - name: Create issues for ESLint violations
            uses: actions/github-script@v6
            with:
              github-token: `${{ secrets.GITHUB_TOKEN }}
              script: |
                const eslintResults = JSON.parse(process.env.ESLINT_RESULTS);
                
                for (const result of eslintResults) {
                  const filePath = result.filePath;
                  
                  for (const message of result.messages) {
                    const title = `[LINT] ${message.ruleId} violation in ${filePath.split('/').pop()}`;
                    const body = `
                    **File:** ${filePath}
                    **Line:** ${message.line}
                    **Column:** ${message.column}
                    **Rule:** ${message.ruleId}
                    
                    **Description:** ${message.message}
                    \`;
                    
                    await github.rest.issues.create({
                      owner: context.repo.owner,
                      repo: context.repo.repo,
                      title: title,
                      body: body,
                      labels: ['technical-debt'],
                      assignees: [context.payload.pull_request.user.login]
                    });
                  }
                }
"@
    $workflowContent | Out-File -FilePath $workflowPath -Encoding utf8
    Register-Resource -Type "File" -Resource $workflowPath
    Write-Status "Created workflow file: $workflowPath" "Green"
    
    # Create component files with linting issues
    if (Get-Confirmation "Create React component files with intentional linting issues?") {
        Write-Status "Creating React component files with intentional linting issues..." "Cyan"
        
        # Create components directory structure if it doesn't exist
        $componentsPath = Join-Path -Path $ProjectPath -ChildPath "src/components"
        $featuresPath = Join-Path -Path $ProjectPath -ChildPath "src/features"
        $servicesPath = Join-Path -Path $ProjectPath -ChildPath "src/services"
        
        # Ensure all required directories exist
        foreach ($dir in @($componentsPath, $featuresPath, $servicesPath)) {
            if (-not (Test-Path -Path $dir)) {
                Write-Status "Creating directory: $dir" "Yellow"
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Status "Created directory: $dir" "Green"
            }
        }
        
        # 1. UserProfile component with camelCase violations
        $userProfilePath = Join-Path -Path $componentsPath -ChildPath "UserProfile.jsx"
        $userProfileContent = @"
    // This component has intentional camelCase violations and unused variables
    import { useState } from 'react';
    import PropTypes from 'prop-types';
    
    const UserProfile = (props) => {
        const user_id = props.userId;  // camelCase violation
        const User_name = props.userName;  // camelCase violation
        const unused_var = "This is unused";  // Unused variable
    
        console.log("Rendering user profile component");  // Console warning
    
        const [bio_text, set_bio_text] = useState(props.bio || '');  // camelCase violations
    
        return (
            <div className="profile-container">
                <h1>User Profile for {User_name}</h1>
                <div className="profile-details">
                    <div>ID: {user_id}</div>
                    <div>Username: {User_name}</div>
                    <textarea
                        value={bio_text}
                        onChange={(e) => set_bio_text(e.target.value)}
                        className="bio-editor"
                    />
                </div>
            </div>
        );
    };
    
    // Missing PropTypes definition
    
    export default UserProfile;
"@
        $userProfileContent | Out-File -FilePath $userProfilePath -Encoding utf8
        Register-Resource -Type "File" -Resource $userProfilePath
        
        # 2. MembershipCard component with quote style and indentation issues
        $membershipCardPath = Join-Path -Path $componentsPath -ChildPath "MembershipCard.jsx"
        $membershipCardContent = @"
    // This component has quote style and indentation issues
    import React from "react";  // Double quotes instead of single
    
    function MembershipCard({ member }) {
      const membershipTypes = {
        "standard": "Standard Membership",
        "premium": "Premium Membership",
        "platinum": "Platinum Membership"
      };
    
        return (  // Incorrect indentation
            <div className="membership-card">
                <div className="card-header">
                    <h3>Carved Rock Fitness</h3>
                    <span className="membership-type">{membershipTypes[member.type]}</span>
                </div>
                <div className="card-body">
                    <div className="member-info">
                        <div className="member-name">{member.firstName} {member.lastName}</div>
                        <div className="member-since">Member since: {new Date(member.joinDate).toLocaleDateString()}</div>
                        <div className="member-id">ID: {member.id}</div>
                    </div>
                </div>
                <div className="card-footer">
                    <div className="expiration">Expires: {new Date(member.expirationDate).toLocaleDateString()}</div>
                </div>
            </div>
        );
    }
    
    // Missing PropTypes
    
    export default MembershipCard;
"@
        $membershipCardContent | Out-File -FilePath $membershipCardPath -Encoding utf8
        Register-Resource -Type "File" -Resource $membershipCardPath
        
        # 3. WorkoutCard component with line length issues
        $workoutCardPath = Join-Path -Path $componentsPath -ChildPath "WorkoutCard.jsx"
        $workoutCardContent = @"
    // This component has line length issues and missing semicolons
    import { useState } from 'react'  // Missing semicolon
    
    const WorkoutCard = ({ workout, onSave }) => {
        const [completed, setCompleted] = useState(workout.completed || false)
        const [feedback, setFeedback] = useState('')  // Missing semicolon
        
        const difficultyLevels = ["Beginner", "Intermediate", "Advanced", "Expert"]
        
        const handleSubmit = () => {
            onSave({ ...workout, completed, feedback, lastModified: new Date().toISOString() })  // This line is intentionally too long and will trigger the max-len rule in ESLint
        }
        
        return (
            <div className="workout-card">
                <h3>{workout.name}</h3>
                <div className="workout-details">
                    <div>Duration: {workout.duration} minutes</div>
                    <div>Difficulty: {difficultyLevels[workout.difficulty]}</div>
                    <div>Target Muscle Groups: {workout.targetMuscles.join(', ')}</div>
                    <div>Calories Burned: {workout.calories}</div>
                    <div className="description">Description: {workout.description}</div>
                </div>
                <div className="workout-tracker">
                    <label>
                        <input 
                            type="checkbox" 
                            checked={completed} 
                            onChange={(e) => setCompleted(e.target.checked)}
                        />
                        Mark as Completed
                    </label>
                    <textarea
                        value={feedback}
                        onChange={(e) => setFeedback(e.target.value)}
                        placeholder="How was your workout? Leave some feedback here to help track your progress over time and make adjustments to your fitness routine based on what works best for your body and goals."  // Line too long
                    />
                    <button onClick={handleSubmit}>Save Progress</button>
                </div>
            </div>
        )  // Missing semicolon
    }
    
    export default WorkoutCard
"@
        $workoutCardContent | Out-File -FilePath $workoutCardPath -Encoding utf8
        Register-Resource -Type "File" -Resource $workoutCardPath
        
        # 4. FeatureClass component with prop-types issues
        $featureClassPath = Join-Path -Path $featuresPath -ChildPath "FeatureClass.jsx"
        $featureClassContent = @"
    // This component is missing prop-types
    import React, { Component } from 'react';
    
    class FeatureClass extends Component {
        constructor(props) {
            super(props);
            this.state = {
                activeTab: 'details',
                data: null,
                loading: false,
                error: null,
                unused_state: 'test'  // Unused state
            };
        }
        
        componentDidMount() {
            this.fetchData();
        }
        
        fetchData = async () => {
            this.setState({ loading: true });
            try {
                // Simulate API call
                const response = await new Promise(resolve => 
                    setTimeout(() => resolve({ data: { name: 'Feature Data' } }), 1000)
                );
                this.setState({ data: response.data, loading: false });
            } catch (error) {
                console.error('Error fetching data:', error);  // Console error
                this.setState({ error: error.message, loading: false });
            }
        }
        
        changeTab = (tab) => {
            this.setState({ activeTab: tab });
        }
        
        render() {
            const { loading, data, error, activeTab } = this.state;
            
            if (loading) return <div>Loading...</div>;
            if (error) return <div>Error: {error}</div>;
            
            return (
                <div className="feature-container">
                    <div className="tabs">
                        <button 
                            className={activeTab === 'details' ? 'active' : ''}
                            onClick={() => this.changeTab('details')}
                        >
                            Details
                        </button>
                        <button 
                            className={activeTab === 'settings' ? 'active' : ''}
                            onClick={() => this.changeTab('settings')}
                        >
                            Settings
                        </button>
                    </div>
                    
                    <div className="tab-content">
                        {activeTab === 'details' && (
                            <div>
                                <h2>Feature Details</h2>
                                {data && <div>{data.name}</div>}
                                <p>{this.props.description}</p>
                            </div>
                        )}
                        
                        {activeTab === 'settings' && (
                            <div>
                                <h2>Feature Settings</h2>
                                <p>Configure feature settings here</p>
                            </div>
                        )}
                    </div>
                </div>
            );
        }
    }
    
    // Missing PropTypes
    
    export default FeatureClass;
"@
        $featureClassContent | Out-File -FilePath $featureClassPath -Encoding utf8
        Register-Resource -Type "File" -Resource $featureClassPath
        
        # 5. ApiService with linting issues
        $apiServicePath = Join-Path -Path $servicesPath -ChildPath "ApiService.js"
        $apiServiceContent = @"
    // This service has various linting issues
    const API_BASE_URL = "https://api.carvedrockfitness.com/v1"  // Missing semicolon and using double quotes
    
    // Function with line length and indentation issues
    export const fetchMembershipPlans = async () => {
        const response = await fetch(`\${API_BASE_URL}/membership/plans`)  // Missing semicolon
        
        if (!response.ok) {
            throw new Error(`Failed to fetch membership plans: \${response.status}`)  // Missing semicolon
        }
        
        return response.json();
    }
    
    // Function with camelCase violations
    export const fetch_user_profile = async (user_id) => {  // camelCase violation
        const response = await fetch(`\${API_BASE_URL}/users/\${user_id}/profile`);
        return response.json();
    }
    
    // Function with multiple issues
    export const processPayment = async (payment_details) => {  // camelCase violation
        console.log("Processing payment", payment_details);  // Console warning and double quotes
        
        const response = await fetch(`\${API_BASE_URL}/payments/process`, {
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
"@
        $apiServiceContent | Out-File -FilePath $apiServicePath -Encoding utf8
        Register-Resource -Type "File" -Resource $apiServicePath
        Write-Status "Created file: $apiServicePath" "Green"
    }
    
    # Linting rule definitions
    $lintingRules = @(
        "camelcase",
        "no-unused-vars",
        "no-console",
        "quotes",
        "semi",
        "indent",
        "max-len",
        "react/prop-types",
        "react/no-unused-state"
    )
    
    $fileNames = @(
        "UserProfile.jsx",
        "MembershipCard.jsx",
        "WorkoutCard.jsx",
        "FeatureClass.jsx",
        "ApiService.js"
    )
    
    # Create feature branches and pull requests
    if (Get-Confirmation "Create feature branches?") {
        Write-Status "Creating feature branches only (no PRs or commits)..." "Cyan"

        $branchNames = @(
            "fix/user-profile-camelcase",
            "fix/membership-card-quotes",
            "fix/workout-card-line-length",
            "fix/feature-class-proptypes",
            "fix/api-service-linting"
        )

        # Make sure we're on main branch to start
        git checkout main

        # Branch that will get a code change
        $branchToModify = "fix/api-service-linting"
        $modifiedBranch = ""

        foreach ($branch in $branchNames) {
            if ($Interactive) {
                $createBranch = Read-Host "Create branch '$branch'? (y/n)"
                if ($createBranch -ne 'y' -and $createBranch -ne 'Y') {
                    Write-Status "Skipping branch $branch" "Yellow"
                    continue
                }
            }
            
            # First, make sure we're on main with a clean working directory
            git checkout main
            
            # Discard any local changes to avoid conflicts
            git reset --hard HEAD
            
            # Create and checkout new branch
            Write-Status "Creating branch: $branch" "Cyan"
            
            # Check if branch exists and handle accordingly
            $branchExists = git branch --list $branch
            if ($branchExists) {
                Write-Status "Branch $branch already exists, switching to it" "Yellow"
                git checkout $branch
                # Reset the branch to match main to ensure we have a clean state
                git reset --hard main
            } else {
                git checkout -b $branch
            }
            
            Register-Resource -Type "Branch" -Resource $branch
            
            # Only make a code change to one specific branch
            if ($branch -eq $branchToModify) {
                $fileToChange = "src/services/ApiService.js"
                
                if (Test-Path $fileToChange) {
                    # Add a comment to simulate a fix
                    $comment = "// Fixed linting issues - $(Get-Date -Format 'yyyy-MM-dd')"
                    $content = Get-Content $fileToChange
                    $content = @($comment) + $content
                    $content | Set-Content $fileToChange
                    
                    Write-Status "Made code change to file: $fileToChange in branch: $branch" "Green"
                    $modifiedBranch = $branch
                } else {
                    Write-Status "File $fileToChange not found!" "Red"
                }
            }
            
            # Return to main branch
            git checkout main
        }
        
        # Output the branch that was modified
        if (-not [string]::IsNullOrEmpty($modifiedBranch)) {
            Write-Status "Branch modified: $modifiedBranch" "Green"
            Write-Status "Only this branch has code changes. All other branches were created but have no changes." "Green"
        } else {
            Write-Status "No branches were modified with code changes." "Yellow"
        }
    }
    
    # Create README with setup instructions
    if (Get-Confirmation "Create DEMO-README.md with setup instructions?") {
        $readmePath = Join-Path -Path $ProjectPath -ChildPath "DEMO-README.md"
        $readmeContent = @"
    # Carved Rock Fitness Linting Demo
    
    This project demonstrates the problem with the current code quality tooling at Carved Rock Fitness.
    
    ## Current Issues
    
    The current setup uses GitHub Actions workflows that automatically trigger whenever a pull request is opened or updated. The workflow runs ESLint for JavaScript files, configured with the company's custom ruleset.
    
    When the linting tools identify issues, the automation creates new GitHub issues with standardized titles like "[LINT] Variable naming violation in user_profile.js" and labels them as "technical-debt". These issues include basic information such as the file path, line number, and a brief description of the violation generated by the linting tool.
    
    ## Demo Files
    
    For this demo, we've added several files with intentional linting issues:
    
    1. `src/components/UserProfile.jsx` - Has camelCase violations and unused variables
    2. `src/components/MembershipCard.jsx` - Has quote style and indentation issues
    3. `src/components/WorkoutCard.jsx` - Has line length issues and missing semicolons
    4. `src/features/FeatureClass.jsx` - Has prop-types issues and unused state
    5. `src/services/ApiService.js` - Has various linting issues including camelCase violations, console statements, and inconsistent quoting
    
    ## GitHub Actions Workflow
    
    The demo includes a GitHub Actions workflow file at `.github/workflows/code-quality-check.yml` that will:
    
    1. Run whenever a pull request is opened or updated
    2. Run ESLint on all JavaScript files
    3. Create GitHub issues for each linting violation
    4. Assign issues to the developer who made the commit
    5. Label issues as "technical-debt"
    
    ## Demo Scenario
    
    When demonstrating this project, you can:
    
    1. Show how the current workflow creates many small issues
    2. Discuss how developers spend roughly 15% of their time addressing these issues
    3. Explain how the descriptions are often too technical or vague
    4. Show how context switching impacts productivity
    5. Present your solution to these problems
    
    ## Next Steps (Post Demo)
    
    After running this demo, you will need to:
    
    1. Create feature branches
    2. Open pull requests
    3. Watch the GitHub Actions workflow create issues
    4. Show how these issues impact developer productivity
    
    ## Rollback Instructions
    
    To reset the demo environment, run the setup script with the -Rollback flag:
    
    ```powershell
    ./setup-demo.ps1 -Rollback
    ```
    
    This will remove:
    - Created GitHub issues
    - Pull requests
    - Feature branches
    - Demo files with linting issues
    
    The script will prompt for confirmation before each major action.
"@
        $readmeContent | Out-File -FilePath $readmePath -Encoding utf8
        Register-Resource -Type "File" -Resource $readmePath
        Write-Status "Created README: $readmePath" "Green"
    }
    
    # Final steps - no commit changes
    Write-Status "Demo environment setup completed!" "Green"

    # Save resource tracking information for rollback
    $resourceTrackingPath = Join-Path -Path $ProjectPath -ChildPath ".demo-resources.json"
    $script:CreatedResources | ConvertTo-Json | Out-File -FilePath $resourceTrackingPath -Encoding utf8
    Write-Status "Saved resource tracking information for rollback" "Green"

    # Skipping committing changes - as requested
    Write-Status "No changes were committed to Git, as requested" "Green"

    # Display final instructions
    Write-Status "Setup complete!" "Green"
    Write-Status "=====================" "Green"
    Write-Status "The demo environment has been successfully configured:" "White"
    Write-Status "1. Created files with intentional linting issues" "White"
    Write-Status "2. Set up GitHub Actions workflow for code quality checking" "White"
    Write-Status "3. Created branches (no PRs or commits)" "White"
    Write-Status "4. Made code changes only to branch: $modifiedBranch" "White"
    Write-Status "5. Documented the setup in DEMO-README.md" "White"
    
    Write-Status "To rollback all changes, run:" "Cyan"
    Write-Status "./setup-demo.ps1 -Rollback" "White"
    
    Write-Status "For interactive mode, run:" "Cyan" 
    Write-Status "./setup-demo.ps1 -Interactive" "White"
    
    Write-Status "Thank you for using the Carved Rock Fitness Demo Setup Script!" "Green"
    
    # Function to open VS Code with the workflow file
    function Open-VSCodeWithWorkflow {
        param([string]$ProjectPath)
        
        $workflowPath = Join-Path -Path $ProjectPath -ChildPath ".github/workflows/code-quality-check.yml"
        
        if (Test-Path -Path $workflowPath) {
            Write-Status "Opening VS Code with workflow file..." "Cyan"
            code $ProjectPath -g $workflowPath
            Write-Status "VS Code opened with workflow file" "Green"
        } else {
            Write-Status "Workflow file not found at $workflowPath" "Red"
        }
    }
    
    # Function to start the app server
    function Start-AppServer {
        param([string]$ProjectPath)
        
        Write-Status "Starting the my-membership app server..." "Cyan"
        
        try {
            Set-Location -Path $ProjectPath
            Start-Process -FilePath "npm" -ArgumentList "run dev" -WorkingDirectory $ProjectPath
            
            # Give the server some time to start
            Start-Sleep -Seconds 5
            
            Write-Status "App server started at http://localhost:5173" "Green"
        } catch {
            Write-Status "Error starting app server: $_" "Red"
        }
    }
    
    # Function to clear GitHub workflow runs
    function Clear-GitHubWorkflowRuns {
        Write-Status "Clearing existing GitHub workflow runs..." "Cyan"
        
        try {
            # List workflow runs and delete them
            $workflowRuns = gh run list --limit 100 --json databaseId 2>$null | ConvertFrom-Json
            
            if ($workflowRuns -and $workflowRuns.Count -gt 0) {
                Write-Status "Found $($workflowRuns.Count) workflow runs to delete" "Yellow"
                
                foreach ($run in $workflowRuns) {
                    # Write-Status "Deleting workflow run ID: $($run.databaseId)" "Yellow"
                    gh run delete $run.databaseId
                }
                
                Write-Status "All workflow runs deleted successfully" "Green"
            } else {
                Write-Status "No workflow runs found to delete" "Green"
            }
        } catch {
            Write-Status "Error clearing GitHub workflow runs: $_" "Red"
            Write-Status "You may need to manually delete workflow runs in the GitHub Actions tab" "Yellow"
        }
    }
    
    # Execute the final setup actions
    if (Get-Confirmation "Open VS Code, start app server, and open browser tabs?") {
        # Clear existing GitHub workflow runs
        if (Get-Confirmation "Clear existing GitHub workflow runs?") {
            Clear-GitHubWorkflowRuns
        }
        
        # Start the app server
        Start-AppServer -ProjectPath $ProjectPath
        
        Write-Status "Final setup actions completed!" "Green"
    }
} catch {
    throw $_
} finally {
    Set-Location -Path $currentPath
}

Write-Status "Demo is now fully configured and running!" "Green"