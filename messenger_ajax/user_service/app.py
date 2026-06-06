from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import os

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

# Получить всех пользователей
@app.route('/api/users', methods=['GET'])
def get_users():
    current_user_id = request.args.get('current_user_id')
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        if current_user_id:
            cur.execute("SELECT id, username, role FROM ajax.users WHERE id != %s ORDER BY username", (current_user_id,))
        else:
            cur.execute("SELECT id, username, role FROM ajax.users ORDER BY username")
        
        users = cur.fetchall()
        return jsonify(users), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
        conn.close()

# Получить пользователя по ID
@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        cur.execute("SELECT id, username, role FROM ajax.users WHERE id = %s", (user_id,))
        user = cur.fetchone()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify(user), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
        conn.close()

# Вход пользователя (просто по имени)
@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    
    if not username:
        return jsonify({'error': 'Username required'}), 400
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Проверяем существование пользователя
        cur.execute("SELECT id, username, role FROM ajax.users WHERE username = %s", (username,))
        user = cur.fetchone()
        
        if not user:
            # Если пользователь не существует, создаем нового (с ролью user)
            cur.execute(
                "INSERT INTO ajax.users (username, role) VALUES (%s, 'user') RETURNING id, username, role",
                (username,)
            )
            user = cur.fetchone()
            conn.commit()
            print(f"Created new user: {user}")
        
        return jsonify({'user': user}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
        conn.close()

# Удалить пользователя (только для админа)
@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    admin_id = request.args.get('admin_id')
    
    if not admin_id:
        return jsonify({'error': 'Admin ID required'}), 400
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        # Проверяем, что админ действительно админ
        cur.execute("SELECT role FROM ajax.users WHERE id = %s", (admin_id,))
        admin = cur.fetchone()
        
        if not admin or admin['role'] != 'admin':
            return jsonify({'error': 'Admin access required'}), 403
        
        # Удаляем сообщения пользователя
        cur.execute("DELETE FROM ajax.messages WHERE sender_id = %s OR receiver_id = %s", (user_id, user_id))
        # Удаляем пользователя
        cur.execute("DELETE FROM ajax.users WHERE id = %s", (user_id,))
        conn.commit()
        
        return jsonify({'message': 'User deleted successfully'}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
        conn.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)