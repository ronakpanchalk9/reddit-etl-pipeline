from airflow import DAG
from datetime import datetime
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

default_args ={
    'owner': 'Ronak Panchal',
    'start_date': datetime(2025,6,8)    
}

file_postfix = datetime.now().strftime("%Y%m%d")
dag = DAG(
    dag_id = "etl_reddit_pipeline",
    default_args=default_args,
    schedule_interval='@daily',
    catchup=False,
    tags=['reddit','etl','pipeline'],
)

