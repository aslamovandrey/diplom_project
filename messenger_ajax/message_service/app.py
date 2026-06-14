from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from datetime import datetime
from prometheus_client import Counter, Histogram, generate_latest
import time

app = Flask(__name__)
CORS(app)

def get_db_connection():
    conn = psycopg2.connect(
        host=os.environ.get("DB_HOST"),
        port=os.environ.get("DB_PORT"),
        database=os.environ.get("DB_NAME"),
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD")
    )
    return conn

REQUEST_COUNT = Counter(
    "message_service_requests_total",
    "Total HTTP requests"
)

REQUEST_LATENCY = Histogram(
    "message_service_request_duration_seconds",
    "Request latency"
)

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    REQUEST_COUNT.inc()
    REQUEST_LATENCY.observe(time.time() - request.start_time)
    return response

@app.route("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype="text/plain"
    )

# Получить все сообщения между двумя пользователями 
@app.route('/api/messages', methods=['GET'])
def get_messages():
    user1_id = request.args.get('user1_id')
    user2_id = request.args.get('user2_id')
    
    if not user1_id or not user2_id:
        return jsonify({'error': 'Both user IDs required'}), 400
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        cur.execute("""
            SELECT m.*, 
                   u1.username as sender_name,
                   u2.username as receiver_name
            FROM ajax.messages m
            JOIN ajax.users u1 ON m.sender_id = u1.id
            JOIN ajax.users u2 ON m.receiver_id = u2.id
            WHERE (sender_id = %s AND receiver_id = %s) 
               OR (sender_id = %s AND receiver_id = %s)
            ORDER BY timestamp ASC
        """, (user1_id, user2_id, user2_id, user1_id))
        
        messages = cur.fetchall()
        return jsonify(messages), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
        conn.close()

# Отправить сообщение
@app.route('/api/messages', methods=['POST'])
def send_message():
    data = request.json
    sender_id = data.get('sender_id')
    receiver_id = data.get('receiver_id')
    content = data.get('content')
    
    if not all([sender_id, receiver_id, content]):
        return jsonify({'error': 'Missing data'}), 400
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        cur.execute(
            "INSERT INTO ajax.messages (sender_id, receiver_id, content) VALUES (%s, %s, %s) RETURNING *",
            (sender_id, receiver_id, content)
        )
        message = cur.fetchone()
        conn.commit()
        
        print(f"Message sent: {sender_id} => {receiver_id}")
        return jsonify(message), 201
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
        conn.close()

# Получить последние сообщения для пользователя (для превью чатов)
@app.route('/api/messages/latest/<int:user_id>', methods=['GET'])
def get_latest_messages(user_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        cur.execute("""
            SELECT DISTINCT ON (other_user_id) 
                other_user_id,
                content,
                timestamp,
                sender_id = %s as is_sent_by_me
            FROM (
                SELECT 
                    CASE 
                        WHEN sender_id = %s THEN receiver_id 
                        ELSE sender_id 
                    END as other_user_id,
                    content,
                    timestamp,
                    sender_id
                FROM ajax.messages 
                WHERE sender_id = %s OR receiver_id = %s
                ORDER BY timestamp DESC
            ) AS subquery
            ORDER BY other_user_id, timestamp DESC
        """, (user_id, user_id, user_id, user_id))
        
        latest = cur.fetchall()
        return jsonify(latest), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
        conn.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002, debug=True)