#!/usr/bin/env python3
import os
import subprocess
import sys
import time
import json
from datetime import datetime

# Define colors for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

# Configuration
LOG_FILE = "azure_agent_walkthrough_results.txt"
# Set to False if you want to simulate commands instead of executing them
EXECUTE_COMMANDS = True

# Initialize log
log_data = {
    "start_time": datetime.now().isoformat(),
    "steps": [],
    "completion_time": None,
    "overall_success": None,
    "notes": ""
}

# Main steps in the walkthrough
steps = [
    {
        "title": "Introduction to the Demo Environment",
        "description": "In this step, we'll introduce the demo environment that's already set up for us.",
        "time": "30 seconds",
        "tasks": [
            "VS Code already opened",
            "Working in the Carved Rock Fitness environment with access to an Azure subscription",
            "Using an ai-agent GitHub repo created to house the code",
            "Azure AI Foundry project already set up for agent deployment"
        ],
        "commands": []  # No commands to execute, just for information
    },
    {
        "title": "Creating the Agent Project",
        "description": "We'll create a dedicated directory for our agent project and set up the necessary environment.",
        "time": "1 minute",
        "tasks": [
            "Create a new directory for the agent project",
            "Create a Python virtual environment",
            "Install required libraries",
            "Create a .env file for Azure credentials",
            "Add .env to .gitignore"
        ],
        "commands": [
            "mkdir -p basic-azure-agent",
            "cd basic-azure-agent",
            "python -m venv venv",
            "source venv/bin/activate || venv\\Scripts\\activate",
            "pip install openai python-dotenv requests",
            "pip freeze > requirements.txt",
            "touch .env",
            "echo 'AZURE_OPENAI_ENDPOINT=https://devops-agent-service.openai.azure.com/\nAZURE_OPENAI_API_KEY=sk-...\nAZURE_OPENAI_DEPLOYMENT_NAME=gpt-4' > .env",
            "echo '.env' >> .gitignore",
            "echo 'venv/' >> .gitignore"
        ]
    },
    {
        "title": "Building the Agent",
        "description": "Now we'll create the agent.py file with our Azure AI agent implementation.",
        "time": "2 minutes",
        "tasks": [
            "Create agent.py file",
            "Implement the basic Azure AI agent class",
            "Set up system prompt and client configuration",
            "Create a question-asking method"
        ],
        "commands": [
            "touch agent.py",
            # The actual file creation is handled specially since it's complex
        ]
    },
    {
        "title": "Preparing a Sample Workflow Log",
        "description": "We'll locate and copy a workflow failure log to analyze with our agent.",
        "time": "1 minute",
        "tasks": [
            "Navigate to the demo data directory",
            "Locate a recent workflow failure log",
            "Copy the log to our project directory",
            "Examine the error in the log"
        ],
        "commands": [
            "cd ~/demo-data",
            "ls -la workflow-logs/",
            "cp workflow-logs/recent-failure.log ~/ai-agent/basic-azure-agent/workflow_error.log",
            "cd ~/ai-agent/basic-azure-agent",
            "cat workflow_error.log | head -20"  # Just view the first 20 lines
        ]
    },
    {
        "title": "Testing the Agent with the Error Log",
        "description": "We'll update our agent to analyze workflow logs and test it with the sample log.",
        "time": "1.5 minutes",
        "tasks": [
            "Update agent.py to focus on workflow log analysis",
            "Modify the system prompt for log analysis",
            "Run the agent with the sample log",
            "Review the agent's analysis"
        ],
        "commands": [
            # These are handled specially since they're file edits
            "python agent.py"
        ]
    },
    {
        "title": "Wrapping Up with Next Steps",
        "description": "We'll commit our changes and summarize what we've achieved.",
        "time": "30 seconds",
        "tasks": [
            "Commit the changes to the repository",
            "Summarize what we've achieved",
            "Preview the next steps"
        ],
        "commands": [
            "git add .",
            "git commit -m 'Initial implementation of workflow analysis agent'",
            "git push"
        ]
    }
]

# Agent.py content for step 3
agent_py_content = '''
import os
import json
from openai import AzureOpenAI
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Create the client
client = AzureOpenAI(
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_key=os.getenv("AZURE_OPENAI_API_KEY"),
    api_version="2023-07-01-preview"
)

class BasicAzureAgent:
    def __init__(self):
        self.deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME")
        self.system_prompt = """
        You are a helpful AI assistant with extensive knowledge about Azure services and DevOps practices.
        Your purpose is to provide clear, accurate information and suggestions when asked questions.

        When answering questions, follow these steps:
        1. Identify the specific topic or issue being asked about
        2. Provide a concise overview of the relevant concepts
        3. Offer specific suggestions or solutions when appropriate
        4. Include code examples when they would be helpful

        Be friendly and conversational in your responses.
        """
        self.client = AzureOpenAI(
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            api_version="2023-07-01-preview"
        )

    def ask_question(self, question):
        """Ask the Azure AI agent a question and get a response."""
        try:
            response = self.client.chat.completions.create(
                model=self.deployment_name,
                messages=[
                    {"role": "system", "content": self.system_prompt},
                    {"role": "user", "content": question}
                ],
                temperature=0.7,
                max_tokens=1000
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"Error asking question: {str(e)}"

# Example usage
if __name__ == "__main__":
    # Create the agent
    agent = BasicAzureAgent()

    # Ask a question
    question = "What are the best practices for implementing CI/CD pipelines in Azure DevOps?"
    answer = agent.ask_question(question)

    # Print the response
    print("\\n=== Azure AI Agent Response ===\\n")
    print(answer)
'''

# Updated agent.py content for step 5
updated_agent_py_content = '''
import os
import json
from openai import AzureOpenAI
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Create the client
client = AzureOpenAI(
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_key=os.getenv("AZURE_OPENAI_API_KEY"),
    api_version="2023-07-01-preview"
)

class BasicAzureAgent:
    def __init__(self):
        self.deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME")
        self.system_prompt = """
        You are a DevOps AI agent that specializes in analyzing GitHub Actions workflow
        failure logs. Your purpose is to identify common patterns in failures and suggest
        possible solutions based on the error messages and context.

        When analyzing a workflow failure log, follow these steps:
        1. Identify the specific error message or failure point
        2. Determine the likely cause of the failure
        3. Suggest potential solutions, ordered by likelihood
        4. If applicable, provide sample code or commands to fix the issue

        Be concise but thorough in your analysis.
        """
        self.client = AzureOpenAI(
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            api_version="2023-07-01-preview"
        )

    def analyze_workflow_log(self, log_content):
        """Analyze a GitHub Actions workflow log to identify failures and suggest fixes."""
        try:
            response = self.client.chat.completions.create(
                model=self.deployment_name,
                messages=[
                    {"role": "system", "content": self.system_prompt},
                    {"role": "user", "content": f"Please analyze this GitHub Actions workflow failure log and provide your recommendations:\\n\\n{log_content}"}
                ],
                temperature=0.3,
                max_tokens=1000
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"Error analyzing workflow log: {str(e)}"

# Example usage
if __name__ == "__main__":
    # Create the agent
    agent = BasicAzureAgent()

    # Load the sample workflow log
    with open("workflow_error.log", "r") as f:
        log_content = f.read()

    # Analyze the log
    analysis = agent.analyze_workflow_log(log_content)

    # Print the analysis
    print("\\n=== AI Agent Analysis ===\\n")
    print(analysis)
'''

def clear_screen():
    """Clear the terminal screen."""
    os.system('cls' if os.name == 'nt' else 'clear')

def print_header(text):
    """Print a formatted header."""
    width = 80
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'=' * width}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text.center(width)}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'=' * width}{Colors.ENDC}\n")

def print_step_info(step, step_num, total_steps):
    """Print information about the current step."""
    print(f"{Colors.BOLD}Step {step_num}/{total_steps}: {step['title']}{Colors.ENDC}")
    print(f"{Colors.CYAN}Estimated time: {step['time']}{Colors.ENDC}")
    print(f"\n{step['description']}\n")
    
    print(f"{Colors.BOLD}Tasks:{Colors.ENDC}")
    for i, task in enumerate(step['tasks'], 1):
        print(f"{Colors.BLUE}{i}. {task}{Colors.ENDC}")
    print()

def execute_command(command, simulate=False):
    """Execute a shell command or simulate it."""
    if simulate:
        print(f"{Colors.WARNING}[SIMULATED] {command}{Colors.ENDC}")
        return True, "Simulated command execution"
    else:
        try:
            result = subprocess.run(command, shell=True, check=True, 
                                   text=True, capture_output=True)
            return True, result.stdout
        except subprocess.CalledProcessError as e:
            return False, f"Error: {e.stderr}"

def create_file(path, content):
    """Create a file with the given content."""
    try:
        with open(path, 'w') as f:
            f.write(content)
        return True, f"Created file: {path}"
    except Exception as e:
        return False, f"Error creating file: {str(e)}"

def get_user_input(prompt, default=None):
    """Get input from the user with an optional default value."""
    if default:
        result = input(f"{prompt} [{default}]: ") or default
    else:
        result = input(f"{prompt}: ")
    return result

def save_log():
    """Save the execution log to a file."""
    log_data["completion_time"] = datetime.now().isoformat()
    
    # First save as JSON for structured data
    with open(LOG_FILE.replace('.txt', '.json'), 'w') as f:
        json.dump(log_data, f, indent=2)
    
    # Then save a readable text version
    with open(LOG_FILE, 'w') as f:
        f.write(f"Azure AI Agent Walkthrough Results\n")
        f.write(f"===============================\n\n")
        f.write(f"Started: {log_data['start_time']}\n")
        f.write(f"Completed: {log_data['completion_time']}\n")
        f.write(f"Overall Success: {log_data['overall_success']}\n\n")
        
        f.write("Step Results:\n")
        for step in log_data["steps"]:
            f.write(f"\n{'-' * 50}\n")
            f.write(f"Step: {step['title']}\n")
            f.write(f"Success: {step['success']}\n")
            if 'reason' in step and step['reason']:
                f.write(f"Reason: {step['reason']}\n")
            f.write(f"Tasks:\n")
            for task in step['tasks']:
                f.write(f"  - {task}\n")
            f.write(f"Commands:\n")
            for cmd in step['commands']:
                f.write(f"  $ {cmd}\n")
        
        if log_data["notes"]:
            f.write(f"\nNotes:\n{log_data['notes']}\n")
    
    print(f"\n{Colors.GREEN}Log saved to {LOG_FILE}{Colors.ENDC}")

def main():
    """Main function to run the walkthrough."""
    clear_screen()
    print_header("Azure AI Agent Walkthrough")
    
    print(f"""
{Colors.BOLD}Welcome to the Azure AI Agent Walkthrough!{Colors.ENDC}

This script will guide you through building an Azure AI agent step by step.
For each step, you'll be shown what needs to be done and prompted to continue.
The script will execute commands for you and ask for feedback on success.
All results will be logged for review.

{Colors.WARNING}Note: Some steps may require manual intervention.{Colors.ENDC}

Press Enter to start the walkthrough...
""")
    input()
    
    total_success = True
    
    # Loop through each step
    for step_num, step in enumerate(steps, 1):
        clear_screen()
        print_header(f"Step {step_num}/{len(steps)}: {step['title']}")
        print_step_info(step, step_num, len(steps))
        
        step_log = {
            "title": step['title'],
            "tasks": step['tasks'],
            "commands": step['commands'],
            "success": True,
            "reason": ""
        }
        
        # Wait for user to be ready
        input(f"{Colors.BOLD}Press Enter to execute this step...{Colors.ENDC}")
        
        # Handle special file creation steps
        if step_num == 3:  # Building the Agent step
            print(f"\n{Colors.CYAN}Creating agent.py file...{Colors.ENDC}")
            success, msg = create_file("agent.py", agent_py_content)
            print(f"{Colors.GREEN if success else Colors.FAIL}{msg}{Colors.ENDC}")
            if not success:
                step_log["success"] = False
                step_log["reason"] = msg
                total_success = False
        elif step_num == 5:  # Updating the Agent step
            print(f"\n{Colors.CYAN}Updating agent.py file...{Colors.ENDC}")
            success, msg = create_file("agent.py", updated_agent_py_content)
            print(f"{Colors.GREEN if success else Colors.FAIL}{msg}{Colors.ENDC}")
            if not success:
                step_log["success"] = False
                step_log["reason"] = msg
                total_success = False
        
        # Execute commands
        for cmd in step['commands']:
            # Skip file creation commands that we handled specially
            if "agent.py" in cmd and (step_num == 3 or step_num == 5):
                continue
                
            print(f"\n{Colors.CYAN}Executing: {cmd}{Colors.ENDC}")
            
            # Execute or simulate the command
            success, output = execute_command(cmd, not EXECUTE_COMMANDS)
            
            # Display truncated output
            if len(output) > 500:
                print(f"{Colors.GREEN if success else Colors.FAIL}{output[:500]}...{Colors.ENDC}")
                print(f"{Colors.WARNING}(Output truncated){Colors.ENDC}")
            else:
                print(f"{Colors.GREEN if success else Colors.FAIL}{output}{Colors.ENDC}")
            
            if not success:
                step_log["success"] = False
                step_log["reason"] = output
                total_success = False
                
            # Pause briefly between commands
            time.sleep(0.5)
        
        # Get user feedback on step success
        print(f"\n{Colors.BOLD}Step completed. Did it succeed? (y/n){Colors.ENDC}")
        success = input().lower() in ['y', 'yes', '']
        
        if not success:
            step_log["success"] = False
            reason = input(f"{Colors.BOLD}Please provide a reason for the failure:{Colors.ENDC} ")
            step_log["reason"] = reason
            total_success = False
        
        # Add step to the log
        log_data["steps"].append(step_log)
        
        # Pause between steps
        if step_num < len(steps):
            input(f"\n{Colors.BOLD}Press Enter to continue to the next step...{Colors.ENDC}")
    
    # Walkthrough complete
    clear_screen()
    print_header("Walkthrough Complete")
    
    print(f"""
{Colors.GREEN if total_success else Colors.WARNING}You have completed the Azure AI Agent walkthrough!{Colors.ENDC}

{Colors.BOLD}Summary:{Colors.ENDC}
- Created a basic AI agent that can analyze GitHub Actions workflow failures
- Demonstrated how AI can quickly identify issues and suggest solutions
- Built a foundation that can be expanded with more advanced capabilities

{Colors.BOLD}Next steps:{Colors.ENDC}
- Enhance the agent to handle more complex scenarios
- Implement specialized log analysis pattern-matching capability
- Integrate the agent with your CI/CD pipeline
""")
    
    # Any additional notes
    print(f"\n{Colors.BOLD}Do you have any additional notes or comments? (Enter to skip){Colors.ENDC}")
    notes = input()
    if notes:
        log_data["notes"] = notes
    
    # Save final status
    log_data["overall_success"] = total_success
    save_log()
    
    print(f"\n{Colors.BOLD}Thank you for completing the walkthrough!{Colors.ENDC}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.WARNING}Walkthrough interrupted by user.{Colors.ENDC}")
        log_data["overall_success"] = False
        log_data["notes"] += "\nWalkthrough was interrupted by user."
        save_log()
        sys.exit(1)