import os
import time
import tensorflow as tf
import numpy as np
from PIL import Image

import json

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(SCRIPT_DIR, "new_best_efficientnetb2_calibrated.keras")
CONFIG_PATH = os.path.join(SCRIPT_DIR, "waste_classifier_config.json")

with open(CONFIG_PATH, "r") as f:
    _config = json.load(f)

IMG_SIZE = tuple(_config.get("img_size", [260, 260]))
TEMPERATURE = float(_config.get("temperature", 1.0))

preprocess_input = tf.keras.applications.efficientnet.preprocess_input

# Load Keras model
model = tf.keras.models.load_model(MODEL_PATH)

def softmax_with_temperature(logits, temperature=1.0):
    logits = np.asarray(logits, dtype=np.float32)
    scaled = logits / temperature
    exp = np.exp(scaled - np.max(scaled))
    return exp / np.sum(exp)

def ai_inference(image):
    """
    Core inference function handling the AI processing of an image.
    Separated from GUI for performance testing.
    """
    if image is None:
        raise ValueError("Empty image input")
        
    img_resized = image.resize(IMG_SIZE)
    img_array = np.array(img_resized, dtype=np.float32)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)

    logits = model.predict(img_array, verbose=0)[0]
    preds = softmax_with_temperature(logits, temperature=TEMPERATURE)
    return preds

def run_and_time(fn, x):
    """
    Timing function specified in the Performance Testing Lab instructions.
    """
    t0 = time.perf_counter()
    try:
        y = fn(x)
        status = "Success"
    except Exception as e:
        y = None
        status = f"Error: {e}"
    t1 = time.perf_counter()
    return status, round(t1 - t0, 3)

def run_performance_tests():
    print("--------------------------------------------------")
    print("      Performance Testing Lab: AI Track           ")
    print("--------------------------------------------------\n")
    
    # Pre-warming the model (optional but recommended for more accurate TFLite metrics)
    # The first inference can be slow due to initialization
    dummy_warmup = Image.new("RGB", (100, 100), color="black")
    try:
        ai_inference(dummy_warmup)
    except Exception:
        pass
    
    # 1. Normal size image upload (e.g., typical 500x500 image)
    print("Case 1: Normal input (500x500 image)")
    normal_image = Image.new("RGB", (500, 500), color="white")
    status, duration = run_and_time(ai_inference, normal_image)
    print(f"Result: {status}")
    print(f"Time Taken: {duration} seconds\n")

    # 2. Big size image upload (e.g., 4000x4000 high-res camera shot)
    print("Case 2: Long input / Big size image upload (4000x4000 image)")
    big_image = Image.new("RGB", (4000, 4000), color="blue")
    status, duration = run_and_time(ai_inference, big_image)
    print(f"Result: {status}")
    print(f"Time Taken: {duration} seconds\n")

    # 3. Empty user input (e.g., user didn't upload or select anything)
    print("Case 3: Empty input (None)")
    empty_image = None
    status, duration = run_and_time(ai_inference, empty_image)
    print(f"Result: {status}")
    print(f"Time Taken: {duration} seconds\n")

if __name__ == "__main__":
    run_performance_tests()
