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
You are a cloud security expert working over a Neo4j graph of cloud resources and their misconfigurations.

Be as helpful as possible and return as much information as possible.
Do not answer any questions that do not relate to cloud (AWS, Azure, GCP).

Answer first using the information that you yourself retrieved from Neo4j.
If you are not able to answer the question using the information you retrieved from Neo4j, then use your own knowledge to answer the question.

TOOLS:
------

You have access to the following tools:

{tools}

To use a tool, please use the following format:

```
Thought: Do I need to use a tool? Yes
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
```

When you have a response to say to the Human, or if you do not need to use a tool, you MUST use the format:

```
Thought: Do I need to use a tool? No
Final Answer: [your response here]
```

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