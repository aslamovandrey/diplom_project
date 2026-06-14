from flask import Flask, render_template, request, redirect, url_for, session, jsonify, Response
import requests
import os
from prometheus_client import Counter, Histogram, generate_latest
import time

app = Flask(__name__)
app.secret_key = 'simple-messenger-secret-key'

REQUEST_COUNT = Counter(
    "wclient_service_requests_total",
    "Total HTTP requests"
)

REQUEST_LATENCY = Histogram(
    "wclient_service_request_duration_seconds",
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

USER_SERVICE_URL = os.environ.get('USER_SERVICE_URL', 'http://localhost:5001')
MESSAGE_SERVICE_URL = os.environ.get('MESSAGE_SERVICE_URL', 'http://localhost:5002')

@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('chat'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        
        try:
            response = requests.post(f'{USER_SERVICE_URL}/api/login', json={'username': username})
            
            if response.status_code == 200:
                user = response.json()['user']
                session['user_id'] = user['id']
                session['username'] = user['username']
                session['role'] = user['role']
                return redirect(url_for('chat'))
            else:
                return render_template('login.html', error='Login failed')
        except Exception as e:
            return render_template('login.html', error=f'Connection error: {str(e)}')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/chat')
def chat():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    return render_template('chat.html', 
                         user_id=session['user_id'],
                         username=session['username'],
                         role=session['role'])

# API для клиента 
@app.route('/api/users')
def get_users():
    if 'user_id' not in session:
        return jsonify({'error': 'Not logged in'}), 401
    
    try:
        response = requests.get(f'{USER_SERVICE_URL}/api/users', 
                              params={'current_user_id': session['user_id']})
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/messages/<int:other_user_id>')
def get_messages(other_user_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not logged in'}), 401
    
    try:
        response = requests.get(f'{MESSAGE_SERVICE_URL}/api/messages',
                              params={'user1_id': session['user_id'], 'user2_id': other_user_id})
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/messages', methods=['POST'])
def send_message():
    if 'user_id' not in session:
        return jsonify({'error': 'Not logged in'}), 401
    
    data = request.json
    data['sender_id'] = session['user_id']
    
    try:
        response = requests.post(f'{MESSAGE_SERVICE_URL}/api/messages', json=data)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/latest-messages')
def get_latest_messages():
    if 'user_id' not in session:
        return jsonify({'error': 'Not logged in'}), 401
    
    try:
        response = requests.get(f'{MESSAGE_SERVICE_URL}/api/messages/latest/{session["user_id"]}')
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'error': 'Admin access required'}), 403
    
    try:
        response = requests.delete(f'{USER_SERVICE_URL}/api/users/{user_id}',
                                 params={'admin_id': session['user_id']})
        return jsonify(response.json()), response.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)