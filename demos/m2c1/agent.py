
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
                    {"role": "user", "content": f"Please analyze this GitHub Actions workflow failure log and provide your recommendations:\n\n{log_content}"}
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
    print("\n=== AI Agent Analysis ===\n")
    print(analysis)
