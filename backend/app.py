import os
import json
import time
import requests
import redis
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, request, jsonify
from flask_cors import CORS
from celery import Celery

app = Flask(__name__)
CORS(app)

DATABASE_URL = os.environ.get('DATABASE_URL', 'postgresql://appuser:apppassword@postgres:5432/appdb')
REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
AUTH_SERVICE_URL = os.environ.get('AUTH_SERVICE_URL', 'http://auth:5001')

# Celery Client to trigger tasks on background worker
celery_client = Celery('tasks', broker=REDIS_URL, backend=REDIS_URL)

def get_db_connection():
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)

def init_db():
    retries = 5
    while retries > 0:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER,
                    task_type VARCHAR(100) NOT NULL,
                    status VARCHAR(50) NOT NULL,
                    payload JSONB,
                    result JSONB,
                    celery_task_id VARCHAR(255),
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
            """)
            conn.commit()
            cur.close()
            conn.close()
            print("✅ Backend API: tasks table initialized")
            return
        except Exception as e:
            print(f"⚠️ Backend DB retry ({retries} left): {e}")
            retries -= 1
            time.sleep(3)

init_db()

def authenticate_request(req):
    auth_header = req.headers.get('Authorization')
    if not auth_header:
        return None, "Authorization header required"
    try:
        res = requests.get(f"{AUTH_SERVICE_URL}/api/auth/verify", headers={"Authorization": auth_header}, timeout=3)
        if res.status_code == 200 and res.json().get('valid'):
            return res.json().get('user'), None
        return None, "Invalid or expired token"
    except Exception as e:
        return None, f"Auth verification failed: {str(e)}"

@app.route('/health', methods=['GET'])
def health_check():
    health = {
        'status': 'healthy',
        'service': 'backend-api',
        'database': 'unknown',
        'redis': 'unknown',
        'timestamp': time.time()
    }
    status_code = 200

    # DB check
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        health['database'] = 'connected'
    except Exception as e:
        health['database'] = f'disconnected: {str(e)}'
        status_code = 503

    # Redis check
    try:
        r = redis.Redis.from_url(REDIS_URL, socket_timeout=2)
        r.ping()
        health['redis'] = 'connected'
    except Exception as e:
        health['redis'] = f'disconnected: {str(e)}'
        status_code = 503

    if status_code != 200:
        health['status'] = 'degraded'

    return jsonify(health), status_code

@app.route('/api/tasks', methods=['POST'])
def create_task():
    user, err = authenticate_request(request)
    if not user:
        return jsonify({'error': err}), 401

    data = request.get_json() or {}
    task_type = data.get('task_type', 'data_crunch')
    payload = data.get('payload', {'number': 42})

    try:
        # Dispatch Celery background task
        async_result = celery_client.send_task(
            'tasks.process_data',
            args=[task_type, payload]
        )

        # Store record in database
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO tasks (user_id, task_type, status, payload, celery_task_id)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id, user_id, task_type, status, celery_task_id, created_at
        """, (user.get('userId'), task_type, 'PENDING', json.dumps(payload), async_result.id))
        new_task = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            'message': 'Task created and dispatched to Celery worker',
            'task': dict(new_task)
        }), 202
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/tasks', methods=['GET'])
def list_tasks():
    user, err = authenticate_request(request)
    if not user:
        return jsonify({'error': err}), 401

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM tasks WHERE user_id = %s ORDER BY created_at DESC LIMIT 50", (user.get('userId'),))
        rows = cur.fetchall()
        cur.close()
        conn.close()

        tasks = []
        for r in rows:
            td = dict(r)
            # Sync with Celery status if pending
            if td['status'] == 'PENDING' and td['celery_task_id']:
                res = celery_client.AsyncResult(td['celery_task_id'])
                if res.ready():
                    td['status'] = res.status
                    td['result'] = res.result
            tasks.append(td)

        return jsonify({'tasks': tasks})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    user, err = authenticate_request(request)
    if not user:
        return jsonify({'error': err}), 401

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM tasks WHERE id = %s AND user_id = %s", (task_id, user.get('userId')))
        row = cur.fetchone()
        cur.close()
        conn.close()

        if not row:
            return jsonify({'error': 'Task not found'}), 404

        task_data = dict(row)
        if task_data['status'] == 'PENDING' and task_data['celery_task_id']:
            res = celery_client.AsyncResult(task_data['celery_task_id'])
            if res.ready():
                task_data['status'] = res.status
                task_data['result'] = res.result

        return jsonify({'task': task_data})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
