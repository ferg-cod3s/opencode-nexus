#!/usr/bin/env python3
"""
Mock OpenCode Server for testing OpenCode Nexus client.
Provides the expected API endpoints for testing chat functionality.
"""

import json
import time
import uuid
from flask import Flask, request, Response
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# In-memory storage for sessions and messages
sessions = {}
messages = {}

@app.route('/app', methods=['GET'])
def get_app_info():
    """Return basic app information"""
    return {
        'name': 'OpenCode Mock Server',
        'version': '1.0.0',
        'status': 'running'
    }

@app.route('/session', methods=['POST'])
def create_session():
    """Create a new chat session"""
    data = request.get_json() or {}
    session_id = str(uuid.uuid4())

    session = {
        'id': session_id,
        'title': data.get('title', 'New Chat Session'),
        'created_at': time.time(),
        'messages': []
    }

    sessions[session_id] = session
    messages[session_id] = []

    return {
        'id': session_id,
        'title': session['title'],
        'created_at': session['created_at']
    }

@app.route('/session/<session_id>/prompt', methods=['POST'])
def send_prompt(session_id):
    """Send a message and return streaming response"""
    if session_id not in sessions:
        return {'error': 'Session not found'}, 404

    data = request.get_json()
    if not data or 'parts' not in data:
        return {'error': 'Invalid request format'}, 400

    # Extract the message content
    message_content = ''
    for part in data['parts']:
        if part.get('type') == 'text':
            message_content += part.get('text', '')

    # Add user message to session
    user_message = {
        'id': str(uuid.uuid4()),
        'role': 'user',
        'content': message_content,
        'timestamp': time.time()
    }
    messages[session_id].append(user_message)

    # Generate AI response
    ai_response_content = f"I received your message: '{message_content}'. This is a mock AI response for testing purposes. The message was sent to session {session_id}."

    def generate_stream():
        # Send chunks of the AI response
        ai_message_id = str(uuid.uuid4())
        words = ai_response_content.split()

        for i, word in enumerate(words):
            chunk = {
                'id': ai_message_id,
                'content': word + ' ',
                'role': 'assistant',
                'timestamp': time.time(),
                'is_chunk': i < len(words) - 1  # False for last chunk
            }

            yield f"data: {json.dumps(chunk)}\n\n"
            time.sleep(0.1)  # Simulate streaming delay

    return Response(generate_stream(), mimetype='text/event-stream')

@app.route('/session/<session_id>/messages', methods=['GET'])
def get_messages(session_id):
    """Get messages for a session"""
    if session_id not in sessions:
        return {'error': 'Session not found'}, 404

    return {'messages': messages.get(session_id, [])}

@app.route('/sessions', methods=['GET'])
def list_sessions():
    """List all sessions"""
    return {'sessions': list(sessions.values())}

if __name__ == '__main__':
    print("Starting Mock OpenCode Server on http://localhost:4096")
    print("API Endpoints:")
    print("  GET  /app - Server info")
    print("  POST /session - Create session")
    print("  POST /session/<id>/prompt - Send message (SSE stream)")
    print("  GET  /session/<id>/messages - Get messages")
    print("  GET  /sessions - List sessions")
    app.run(host='127.0.0.1', port=4096, debug=True)