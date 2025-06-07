# FROM apache/airflow:2.7.3-python3.9

# USER root
# RUN apt-get update && apt-get install -y gcc libpq-dev && apt-get clean

# COPY requirements.txt /requirements.txt
# USER airflow
# RUN pip install --no-cache-dir -r /requirements.txt

