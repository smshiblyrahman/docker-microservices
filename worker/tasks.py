import os
import time
import json
import psycopg2
from celery import Celery

REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
DATABASE_URL = os.environ.get('DATABASE_URL', 'postgresql://appuser:apppassword@postgres:5432/appdb')

app = Celery('tasks', broker=REDIS_URL, backend=REDIS_URL)

app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    worker_prefetch_multiplier=1,
)

def update_db_task_result(celery_task_id, status, result):
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("""
            UPDATE tasks
            SET status = %s, result = %s, updated_at = CURRENT_TIMESTAMP
            WHERE celery_task_id = %s
        """, (status, json.dumps(result), celery_task_id))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"⚠️ Failed to update task status in DB: {e}")

@app.task(bind=True, name='tasks.process_data')
def process_data(self, task_type, payload):
    task_id = self.request.id
    print(f"⚙️ Celery Worker: Starting task {task_id} of type '{task_type}'...")
    
    # Simulate meaningful background computational workload
    time.sleep(2)
    
    if task_type == 'calculate_primes':
        limit = payload.get('limit', 100)
        primes = []
        for num in range(2, limit + 1):
            if all(num % i != 0 for i in range(2, int(num ** 0.5) + 1)):
                primes.append(num)
        result = {'total_primes': len(primes), 'sample': primes[:10]}
    elif task_type == 'data_crunch':
        num = payload.get('number', 10)
        result = {
            'number': num,
            'square': num ** 2,
            'cube': num ** 3,
            'factorial_digits': len(str(math_fact(min(num, 100))))
        }
    else:
        result = {
            'status': 'completed',
            'echo_payload': payload,
            'processed_at': time.time()
        }

    update_db_task_result(task_id, 'SUCCESS', result)
    print(f"✅ Celery Worker: Task {task_id} completed successfully!")
    return result

def math_fact(n):
    f = 1
    for i in range(2, n + 1):
        f *= i
    return f
