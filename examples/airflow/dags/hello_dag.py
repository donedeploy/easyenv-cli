"""A trivial Airflow DAG that prints hello on every run."""
from datetime import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator


def say_hello() -> None:
    print("hello easyenv")


with DAG(
    dag_id="hello_easyenv",
    description="Trivial hello-world DAG synced from easyenv-cli/examples/airflow.",
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False,
    tags=["easyenv", "hello"],
) as dag:
    PythonOperator(
        task_id="say_hello",
        python_callable=say_hello,
    )
