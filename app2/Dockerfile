# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt ./

# Install any needed packages specified in requirements.txt
# Use --no-cache-dir to reduce image size
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container at /app
# This includes your Streamlit app script (e.g., bot.py) and any other modules.
# Ensure sensitive files like secrets.toml are excluded via .dockerignore
COPY . .

# Make port 8501 available to the world outside this container (Streamlit's default port)
EXPOSE 8501

# Define environment variable for Streamlit health check
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health

# ENV ST_OPENAI_API_KEY="sk-proj-..."
# ENV ST_OPENAI_MODEL="gpt-4o"
# ENV ST_NEO4J_URI="neo4j+s://2712aa2e.databases.neo4j.io"
# ENV ST_NEO4J_USERNAME="neo4j"
# ENV ST_NEO4J_PASSWORD="password"

# Run bot.py when the container launches
ENTRYPOINT ["streamlit", "run", "bot.py", "--server.port=8501", "--server.address=0.0.0.0"]