from llm import llm
from graph import graph
from langchain_core.prompts import ChatPromptTemplate, PromptTemplate
from langchain.schema import StrOutputParser
from langchain.tools import Tool
from langchain_neo4j import Neo4jChatMessageHistory
from langchain.agents import AgentExecutor, create_react_agent
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain import hub
from utils import get_session_id
from tools.cypher import cypher_qa


# Create a cloud chat chain
chat_prompt = ChatPromptTemplate.from_messages(
    [
        ("system", "You are a cloud security expert providing information about cloud misconfigurations."),
        ("human", "{input}"),
    ]
)


cloud_chat = chat_prompt | llm | StrOutputParser()

# Create a set of tools
tools = [
    Tool.from_function(
        name="General Chat",
        description="For general cloud misconfiguration chat not covered by other tools",
        func=cloud_chat.invoke,
    ),
    Tool.from_function(
        name="Cloud Misconfiguration information",
        description="Provide information about Cloud Misconfiguration questions using Cypher",
        func = cypher_qa
    )
]

# Create chat history callback
def get_memory(session_id):
    return Neo4jChatMessageHistory(session_id=session_id, graph=graph)


# Define the Agent prompt
agent_prompt = PromptTemplate.from_template("""
You run in a loop of Thought, Action, Action Input, Observation.
At the end of the loop you output an Answer
Use Thought to describe your thoughts about the question you have been asked.
Use Action to run one of the actions available to you - the input of the action will be the Action Input
Observation will be the result of running those actions.

Your available actions are:
{tools}

To use a tool, please use the following format:

Thought: I should retreive this information from Neo4j Graph Database using a tool
Action: the name of the action to take, must be one of [{tool_names}]
Action Input: The input to the action
Observation: the result of the action

When you have a response to say to the Human, or if you do not need to use a tool, you MUST use the format:

```
Thought: I need to respond now
Final Answer: [your response here]

Example session:

Question: Which RDS instances have encryption turned off?
Thought: I should retreive this information using Neo4j Graph Database using Cloud Misconfiguration information
Action: Cloud Misconfiguration information
Action Input: {{"query": "MATCH (rds:RDSInstance) WHERE rds.encryption = false RETURN rds.id"}}

You will be called again with this:

Observation: 'prod-db-2, prod-db-1'

Thought:I need to respond now

Final Answer: The RDS instances with IDs 'prod-db-2' and 'prod-db-1' have encryption turned off in your AWS account

Begin!

Previous conversation history:
{chat_history}

New input: {input}
{agent_scratchpad}
""")

# Create the agent
agent = create_react_agent(llm, tools, agent_prompt)
agent_executor = AgentExecutor(
    agent=agent,
    tools=tools,
    handle_parsing_errors=True,
    verbose=True
    )

chat_agent = RunnableWithMessageHistory(
    agent_executor,
    get_memory,
    input_messages_key="input",
    history_messages_key="chat_history",
)

# Create a handler to call the agent
def generate_response(user_input):
    """
    Create a handler that calls the Conversational agent
    and returns a response to be rendered in the UI
    """

    response = chat_agent.invoke(
        {"input": user_input},
        {"configurable": {"session_id": get_session_id()}},)

    return response['output']