#!/usr/bin/env python3
"""
Simple test script to verify OpenCode client can connect to a server
"""

import requests
import json
import sys

def test_server_connection(hostname, port, secure=False):
    """Test connection to OpenCode server"""
    protocol = "https" if secure else "http"
    url = f"{protocol}://{hostname}:{port}/app"
    
    print(f"Testing connection to: {url}")
    
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            print("✅ Connection successful!")
            try:
                data = response.json()
                print(f"Server info: {json.dumps(data, indent=2)}")
                return True
            except:
                print("✅ Server responded but no JSON data")
                return True
        else:
            print(f"❌ Server returned status: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Failed to connect - server may be down")
        return False
    except requests.exceptions.Timeout:
        print("❌ Connection timeout")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def test_chat_session(hostname, port, secure=False):
    """Test creating a chat session"""
    protocol = "https" if secure else "http"
    url = f"{protocol}://{hostname}:{port}/session"
    
    print(f"\nTesting chat session creation: {url}")
    
    try:
        response = requests.post(url, json={"title": "Test Session"}, timeout=10)
        if response.status_code == 200:
            print("✅ Chat session created successfully!")
            try:
                data = response.json()
                print(f"Session info: {json.dumps(data, indent=2)}")
                return data.get("id")
            except:
                print("✅ Session created but no JSON data")
                return None
        else:
            print(f"❌ Failed to create session: {response.status_code}")
            print(f"Response: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Error creating session: {e}")
        return None

def main():
    # Test with a local OpenCode server if available
    test_cases = [
        ("localhost", 63701, False),  # Local HTTP (from summary)
        ("localhost", 4096, False),   # Local HTTP (fallback)
        ("localhost", 8443, True),    # Local HTTPS
        ("opencode.example.com", 443, True),  # Remote server
    ]
    
    for hostname, port, secure in test_cases:
        print(f"\n{'='*50}")
        print(f"Testing: {hostname}:{port} (secure: {secure})")
        print('='*50)
        
        # Test basic connection
        if test_server_connection(hostname, port, secure):
            # Test chat session
            session_id = test_chat_session(hostname, port, secure)
            if session_id:
                print(f"✅ Full integration test passed for {hostname}:{port}")
            else:
                print(f"⚠️  Connection worked but chat session failed for {hostname}:{port}")
        else:
            print(f"❌ Connection test failed for {hostname}:{port}")

if __name__ == "__main__":
    main()