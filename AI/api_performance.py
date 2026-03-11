import time
import requests
import os

# Backend URL (assuming default development port 3000)
BASE_URL = "http://localhost:3000"

# Note: This script assumes the backend is running.
# If it's not running, we'll catch the error.

print("\n" + "=" * 85)
print(f"{'API call':<40} | {'Result (sec)':<15} | {'Identified Bottleneck'}")
print("-" * 85)

endpoints = [
    ("/health", "Basic health check"),
    ("/health/ai", "AI service proxy"),
    ("/health/blockchain", "Blockchain health check")
]

for endpoint, description in endpoints:
    url = f"{BASE_URL}{endpoint}"
    try:
        start = time.time()
        response = requests.get(url, timeout=5)
        end = time.time()
        duration = end - start
        
        bottleneck = "None"
        if duration > 1.0:
            bottleneck = "Network request delay"
        elif endpoint == "/health/ai" and duration > 0.5:
            bottleneck = "Cross-service latency"
            
        print(f"{endpoint:<40} | {duration:<15.4f} | {bottleneck}")
    except requests.exceptions.ConnectionError:
        print(f"{endpoint:<40} | {'FAILED':<15} | Backend server not running")
    except Exception as e:
        print(f"{endpoint:<40} | {'ERROR':<15} | {str(e)[:30]}")

print("=" * 85 + "\n")
