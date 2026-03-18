import os
import json
import tkinter as tk
from tkinter import ttk, messagebox
from PIL import Image, ImageTk, ImageGrab
import numpy as np
import tensorflow as tf

# -------------------------------------------------
# Configuration
# -------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(SCRIPT_DIR, "new_best_efficientnetb2_calibrated.keras")
CONFIG_PATH = os.path.join(SCRIPT_DIR, "waste_classifier_config.json")

if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(f"Model not found: {MODEL_PATH}")

if not os.path.exists(CONFIG_PATH):
    raise FileNotFoundError(f"Config not found: {CONFIG_PATH}")

with open(CONFIG_PATH, "r") as f:
    config = json.load(f)

CLASS_NAMES = config["class_names"]
IMG_SIZE = tuple(config["img_size"])
TEMPERATURE = float(config["temperature"])
CONFIDENCE_THRESHOLD = float(config["confidence_threshold"])
MARGIN_THRESHOLD = float(config["margin_threshold"])

# -------------------------------------------------
# Load model
# -------------------------------------------------
model = tf.keras.models.load_model(MODEL_PATH, compile=False)
print("Loaded model:", MODEL_PATH)
print("Loaded config:", CONFIG_PATH)
print("Classes:", CLASS_NAMES)
print("Temperature:", TEMPERATURE)

# -------------------------------------------------
# Helper functions
# -------------------------------------------------
def softmax_with_temperature(logits, temperature=1.0):
    logits = np.asarray(logits, dtype=np.float32)
    scaled = logits / temperature
    exp = np.exp(scaled - np.max(scaled))
    return exp / np.sum(exp)

def prepare_input(image: Image.Image):
    image = image.convert("RGB")
    image = image.resize(IMG_SIZE)

    img_array = np.array(image, dtype=np.float32)
    img_array = np.expand_dims(img_array, axis=0)

    # Do NOT call preprocess_input here.
    # The model already does preprocess_input internally.
    return img_array

def predict_with_reject(probs, class_names, conf_thresh=0.60, margin_thresh=0.15):
    order = np.argsort(probs)[::-1]
    top1_idx = int(order[0])
    top2_idx = int(order[1])

    top1_conf = float(probs[top1_idx])
    top2_conf = float(probs[top2_idx])
    margin = top1_conf - top2_conf

    if top1_conf < conf_thresh or margin < margin_thresh:
        label = "Unknown / not confident"
    else:
        label = class_names[top1_idx]

    return {
        "label": label,
        "top1_index": top1_idx,
        "top2_index": top2_idx,
        "top1_confidence": top1_conf,
        "top2_confidence": top2_conf,
        "margin": margin,
    }

def predict_image(image: Image.Image):
    img_array = prepare_input(image)

    logits = model.predict(img_array, verbose=0)[0]
    probs = softmax_with_temperature(logits, temperature=TEMPERATURE)

    decision = predict_with_reject(
        probs,
        CLASS_NAMES,
        conf_thresh=CONFIDENCE_THRESHOLD,
        margin_thresh=MARGIN_THRESHOLD
    )

    top3_idx = np.argsort(probs)[-3:][::-1]
    top3 = [(CLASS_NAMES[i], float(probs[i]) * 100.0) for i in top3_idx]

    return decision, top3

def run_inference(image: Image.Image, source="Clipboard"):
    decision, top3 = predict_image(image)

    display_img = image.convert("RGB").resize((320, 320))
    tk_img = ImageTk.PhotoImage(display_img)

    image_label.config(image=tk_img, text="")
    image_label.image = tk_img

    top3_text = "\n".join(
        [f"{i+1}. {name}: {score:.2f}%" for i, (name, score) in enumerate(top3)]
    )

    result_label.config(
        text=(
            f"Source: {source}\n\n"
            f"Decision:\n{decision['label']}\n\n"
            f"Top 1 Confidence:\n{decision['top1_confidence'] * 100:.2f}%\n\n"
            f"Top 1 vs Top 2 Margin:\n{decision['margin'] * 100:.2f}%\n\n"
            f"Top 3 Predictions:\n{top3_text}"
        )
    )

    status_label.config(text="Prediction complete")

def paste_image(event=None):
    status_label.config(text="Reading clipboard...")
    root.update_idletasks()

    try:
        clipboard_data = ImageGrab.grabclipboard()

        if isinstance(clipboard_data, Image.Image):
            run_inference(clipboard_data, source="Clipboard")
        else:
            status_label.config(text="Clipboard does not contain an image")
            messagebox.showwarning("No Image", "Clipboard does not contain an image.")
    except Exception as e:
        status_label.config(text="Paste failed")
        messagebox.showerror("Error", f"Failed to paste image:\n{e}")

def clear_result():
    image_label.config(image="", text="No image pasted")
    image_label.image = None
    result_label.config(text="Paste an image from your browser using Ctrl+V")
    status_label.config(text="Ready")

# -------------------------------------------------
# GUI
# -------------------------------------------------
root = tk.Tk()
root.title("Waste Classification Test")
root.geometry("520x780")
root.resizable(False, False)

root.bind("<Control-v>", paste_image)
root.bind("<Control-V>", paste_image)

title_label = ttk.Label(
    root,
    text="Waste Classification Model Tester",
    font=("Segoe UI", 16, "bold")
)
title_label.pack(pady=10)

hint_label = ttk.Label(
    root,
    text="Copy an image from your browser, then press Ctrl+V",
    font=("Segoe UI", 10)
)
hint_label.pack()

button_frame = ttk.Frame(root)
button_frame.pack(pady=10)

ttk.Button(
    button_frame,
    text="Paste Image",
    command=paste_image
).grid(row=0, column=0, padx=5)

ttk.Button(
    button_frame,
    text="Clear",
    command=clear_result
).grid(row=0, column=1, padx=5)

image_label = ttk.Label(
    root,
    text="No image pasted",
    anchor="center"
)
image_label.pack(pady=15)

result_label = ttk.Label(
    root,
    text="Paste an image from your browser using Ctrl+V",
    font=("Segoe UI", 11),
    justify="center"
)
result_label.pack(pady=10)

status_label = ttk.Label(
    root,
    text="Ready",
    font=("Segoe UI", 9)
)
status_label.pack(pady=10)

root.mainloop()