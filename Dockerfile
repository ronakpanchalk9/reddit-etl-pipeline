# # Use a slim Python base image
# FROM python:3.9-slim-buster AS base

# ARG AIRFLOW_VERSION=3.0.0
# # Python and OS-level dependencies often needed by Airflow or common providers
# # Keep this list minimal to what you actually need
# ENV PYTHON_VERSION=3.9 \
#     AIRFLOW_HOME=/opt/airflow \
#     DEBIAN_FRONTEND=noninteractive


# # Create airflow user and group
# RUN groupadd -g 999 airflow && useradd -u 999 -g airflow -ms /bin/bash airflow

# # Copy requirements first to leverage Docker cache
# COPY requirements.txt /requirements.txt
# # It's good practice to upgrade pip
# RUN pip install --no-cache-dir --upgrade pip
# # Install Airflow and other Python dependencies
# # Use constraints for reproducible builds
# RUN pip install --no-cache-dir \
#     "apache-airflow==${AIRFLOW_VERSION}" \
#     # Example: if using psycopg2 (Postgres hook)
#     # "apache-airflow-providers-postgres" \
#     # Install from your requirements file
#     -r /requirements.txt

# # Copy remaining application code
# # Only copy what's necessary for the Airflow services
# COPY ./config /opt/airflow/config
# COPY ./dags /opt/airflow/dags
# # COPY ./data /opt/airflow/data # If static data is needed in image
# COPY ./etls /opt/airflow/etls
# COPY ./logs /opt/airflow/logs
# COPY ./pipelines /opt/airflow/pipelines
# # COPY ./tests /opt/airflow/tests # Usually not for runtime
# COPY ./utils /opt/airflow/utils

# # Set ownership and permissions
# RUN chown -R airflow:airflow ${AIRFLOW_HOME} \
#     && chmod -R 755 ${AIRFLOW_HOME}

# USER airflow
# WORKDIR ${AIRFLOW_HOME}

# Default entrypoint (Airflow's default entrypoint script is usually good)
# ENTRYPOINT ["/entrypoint.sh"]
# CMD ["bash"] # Or your default command if not using Airflow's entrypoint

FROM apache/airflow:2.7.1-python3.9

COPY requirements.txt /opt/airflow/

USER root
RUN apt-get update && apt-get install -y gcc python3-dev

USER airflow

RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt