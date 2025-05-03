import streamlit as st
from llm import llm
from graph import graph
from langchain_neo4j import GraphCypherQAChain
from langchain.prompts.prompt import PromptTemplate


CYPHER_GENERATION_TEMPLATE = """
You are an expert Neo4j Developer translating user questions into Cypher to answer questions about public cloud resources and its misconfigurations.
Convert the user's question based on the schema.

Use only the provided relationship types and properties in the schema.
Do not use any other relationship types or properties that are not provided.

Fine-tune the Cypher query:
When you write the RETURN clause, alias every property to a camelCase name that does not include dots or the label prefix, e.g. RETURN rds.db_instance_identifier AS rdsInstanceName

Example Questions and Cypher Statements:

1. What RDS instances are installed in my AWS accounts?
```
MATCH (aws:AWSAccount)-[r:RESOURCE]->(rds:RDSInstance) 
RETURN *
```

2. Which RDS instances have encryption turned off?
```
MATCH (a:AWSAccount)-[:RESOURCE]->(rds:RDSInstance{{storage_encrypted:false}}) 
RETURN a.name, rds.id
```

3. Which EC2 instances are exposed (directly or indirectly) to the internet?
```
MATCH (instance:EC2Instance{{exposed_internet: true}}) 
RETURN instance.instanceid, instance.publicdnsname
```

4. Which ELB LoadBalancers are internet accessible?
```
MATCH (elb:LoadBalancer{{exposed_internet: true}})—->(listener:ELBListener) 
RETURN elb.dnsname, listener.port ORDER by elb.dnsname, listener.port
```

5. Which S3 buckets have a policy granting any level of anonymous access to the bucket?
```
MATCH (s:S3Bucket) WHERE s.anonymous_access = true 
RETURN s
```

6. What are the possible labels for all nodes connected to all EC2 instance nodes in my graph?
```
MATCH (d:EC2Instance)--(n) 
RETURN distinct labels(n);
```

Schema:
{schema}

Question:
{question}


If the answer is obvious from any column called `name`, `instanceName`, `resourceName`, or from the first two rows, answer in one concise sentence.

If one or more rows are present, answer in one sentence by naming the resources listed.
If no rows are present, answer exactly: "No matching rows."

Do NOT say "I don't know the answer."

"""

cypher_prompt = PromptTemplate.from_template(CYPHER_GENERATION_TEMPLATE)


# Create the Cypher QA chain
cypher_qa = GraphCypherQAChain.from_llm(
    llm,
    graph=graph,
    verbose=True,
    cypher_prompt=cypher_prompt,
    allow_dangerous_requests=True
)