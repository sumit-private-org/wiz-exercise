import streamlit as st
from llm import llm
from graph import graph
from langchain_neo4j import GraphCypherQAChain
from langchain.prompts.prompt import PromptTemplate


CYPHER_GENERATION_TEMPLATE = """
You are a Neo4j Subject Matter Expert that translates user questions into Neo4j Cypher query and interprets the results of a Neo4j Cypher query and provides a clear, concise, human-readable summary.
Convert the user's question based on the schema.

Instructions:
Use only the provided relationship types and properties in the schema.
Do not use any other relationship types or properties that are not provided.

Examples:

1. What RDS instances are installed in my AWS accounts?
MATCH (aws:AWSAccount)-[r:RESOURCE]->(rds:RDSInstance) 
RETURN *

2. Which RDS instances have encryption turned off?
MATCH (rds:RDSInstance{{storage_encrypted:false}}) 
RETURN rds.id

3. Which EC2 instances are exposed (directly or indirectly) to the internet?
MATCH (instance:EC2Instance{{exposed_internet: true}}) 
RETURN instance.instanceid

4. Which ELB LoadBalancers are internet accessible?
MATCH (elb:LoadBalancer{{exposed_internet: true}})—->(listener:ELBListener) 
RETURN elb.dnsname, listener.port ORDER by elb.dnsname, listener.port

5. Which S3 buckets have a policy granting any level of anonymous access to the bucket?
MATCH (s:S3Bucket) WHERE s.anonymous_access = true 
RETURN s

6. What are the possible labels for all nodes connected to all EC2 instance nodes in my graph?
MATCH (d:EC2Instance)--(n) 
RETURN distinct labels(n);

Schema: {schema}

Question: {question}
"""

#cypher_prompt = PromptTemplate.from_template(CYPHER_GENERATION_TEMPLATE)
cypher_prompt = PromptTemplate(
    template=CYPHER_GENERATION_TEMPLATE,
    input_variables=["schema", "question"],
)

# Create the Cypher QA chain
cypher_qa = GraphCypherQAChain.from_llm(
    llm,
    graph=graph,
    verbose=True,
    cypher_prompt=cypher_prompt,
    allow_dangerous_requests=True
)