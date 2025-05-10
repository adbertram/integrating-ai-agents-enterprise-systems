import os
from dotenv import load_dotenv
from openai import AzureOpenAI

load_dotenv()

client = AzureOpenAI(
    api_key=os.getenv("AZURE_OPENAI_API_KEY"),
    api_version="2023-07-01-preview",
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
)

class BasicAzureAgent:
    def __init__(self):
        self.client = client
        self.deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME")
        self.system_prompt = """
        You are a helpful AI assistant with extensive knowledge about Azure services and DevOps practices.
        Your purpose is to provide clear, accurate information and suggestions when asked questions.
        """

    def ask_question(self, question):
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

if __name__ == "__main__":
    agent = BasicAzureAgent()
    print(agent.ask_question("What are the best practices for implementing CI/CD pipelines in Azure DevOps?"))