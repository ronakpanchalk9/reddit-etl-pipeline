# Use a slim Python base image
FROM python:3.9-slim-buster AS base

ARG AIRFLOW_VERSION=3.0.0
# Set AIRFLOW_HOME and other environment variables
ENV PYTHON_VERSION=3.9 \
    AIRFLOW_HOME=/opt/airflow \
    DEBIAN_FRONTEND=noninteractive \
    # Recommended for resource-constrained environments
    AIRFLOW__CORE__DAG_PROCESSOR_MANAGER_QUEUE_SIZE=2 \
    AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC=15 \
    AIRFLOW__SCHEDULER__JOB_HEARTBEAT_SEC=15 \
    AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL=300

# Create airflow user and group first
# Using fixed IDs for reproducibility and to avoid permission issues with volumes
RUN groupadd -g 999 airflow && \
    useradd -u 999 -g airflow -m -s /bin/bash airflow

# System dependencies
# psycopg2-binary needs libpq-dev, curl for healthchecks if needed inside image
# build-essential and other -dev packages for compiling some python packages if needed from requirements.txt
# Keep this minimal.
RUN apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        libpq-dev \
        # Add other OS deps your DAGs/providers might need, e.g. freetds-dev for mssql
        # For some python packages:
        # build-essential \ 
        # git \ # If installing packages from git
        curl \
        dumb-init \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt /requirements.txt

# Upgrade pip and install Python dependencies
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
        "apache-airflow==${AIRFLOW_VERSION}" \
        "psycopg2-binary>=2.8" \ 
        # Add other providers if you use them, e.g.:
        # "apache-airflow-providers-cncf-kubernetes" \
        # "apache-airflow-providers-docker" \
        # Install from your requirements file \
        -r /requirements.txt

        RUN pip install --no-cache-dir --upgrade pip \
        && pip install --no-cache-dir \
            "apache-airflow==${AIRFLOW_VERSION}" \
            "psycopg2-binary>=2.8" \
            -r /requirements.txt
    
# --- TEMPORARY DEBUGGING ---
RUN echo "Trying to find where pip installed airflow scripts:" && \
    pip show apache-airflow && \
    echo "--- Checking common bin locations for airflow user ---" && \
    ls -l /home/airflow/.local/bin || echo "/home/airflow/.local/bin not found or empty" && \
    echo "--- Checking common system bin locations ---" && \
    ls -l /usr/local/bin || echo "/usr/local/bin not found or empty" && \
    echo "--- Listing files in airflow site-packages to find scripts (if any) ---" && \
    python -m site --user-site # This will show the user site-packages directory
    # Then you might need to manually look into the shown directory's sibling 'bin' folder.
    # For example, if user site is /home/airflow/.local/lib/python3.9/site-packages,
    # then the scripts are likely in /home/airflow/.local/bin
# --- END TEMPORARY DEBUGGING ---

# Create necessary directories that will be mounted as volumes
# This ensures they exist with correct base permissions even if host mounts are empty initially.
# Logs and data are runtime, so just create dirs. Config, dags, plugins copied below.
RUN mkdir -p ${AIRFLOW_HOME}/logs ${AIRFLOW_HOME}/data ${AIRFLOW_HOME}/plugins

# Copy application code and config AFTER dependencies are installed
COPY ./config ${AIRFLOW_HOME}/config
COPY ./dags ${AIRFLOW_HOME}/dags
# COPY ./plugins ${AIRFLOW_HOME}/plugins # Already created, content will come from volume
# For custom python modules imported by DAGs:
COPY ./etls ${AIRFLOW_HOME}/etls
COPY ./pipelines ${AIRFLOW_HOME}/pipelines
COPY ./utils ${AIRFLOW_HOME}/utils
# COPY ./tests ${AIRFLOW_HOME}/tests

# Set ownership and permissions
# Ensure AIRFLOW_HOME and all its contents are owned by airflow user
RUN chown -R airflow:airflow ${AIRFLOW_HOME} \
    && chmod -R 755 ${AIRFLOW_HOME} \
    && chmod +x /entrypoint.sh || true # In case entrypoint.sh isn't executable from base

USER airflow
WORKDIR ${AIRFLOW_HOME}

# Airflow's default entrypoint script handles basic setup.
# It's copied into the path when apache-airflow is installed.
# dumb-init helps with signal handling and zombie reaping.
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/entrypoint.sh"]
# Default command if none is provided to `docker run` or in docker-compose `command`.
# For services like webserver/scheduler, this will be overridden.
CMD ["bash"]
