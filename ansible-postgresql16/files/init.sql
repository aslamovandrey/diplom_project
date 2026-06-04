CREATE SCHEMA IF NOT EXISTS ajax;

-- Создание таблицы пользователей
CREATE TABLE IF NOT EXISTS ajax.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание таблицы сообщений
CREATE TABLE IF NOT EXISTS ajax.messages (
    id SERIAL PRIMARY KEY,
    sender_id INTEGER REFERENCES ajax.users(id) ON DELETE CASCADE,
    receiver_id INTEGER REFERENCES ajax.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание администратора по умолчанию
INSERT INTO ajax.users (username, role) VALUES ('admin', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Создание тестового пользователя
INSERT INTO ajax.users (username, role) VALUES ('user1', 'user')
ON CONFLICT (username) DO NOTHING;

INSERT INTO ajax.users (username, role) VALUES ('user2', 'user')
ON CONFLICT (username) DO NOTHING;