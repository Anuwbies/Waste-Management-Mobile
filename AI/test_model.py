import os
import random
import tkinter as tk
from tkinter import ttk
from PIL import Image, ImageTk, ImageGrab
import tensorflow as tf
import numpy as np

# -------------------------------------------------
# Configuration
# -------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(SCRIPT_DIR, "final_model.tflite")
TEST_DATASET_DIR = os.path.join(SCRIPT_DIR, "test")  # <-- labeled test dataset

IMG_SIZE = (260, 260)

preprocess_input = tf.keras.applications.efficientnet.preprocess_input

CLASS_NAMES = [
    "E-waste",
    "Automobile",
    "Battery",
    "Glass",
    "Light Bulb",
    "Metal",
    "Organic",
    "Paper",
    "Plastic"
]

VALID_EXTENSIONS = (".jpg", ".jpeg", ".png")

# -------------------------------------------------
# Load TFLite model
# -------------------------------------------------
interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# -------------------------------------------------
# Evaluate TFLite model accuracy
# -------------------------------------------------
def evaluate_tflite_accuracy():
    correct = 0
    total = 0

    for label_index, class_name in enumerate(CLASS_NAMES):
        class_dir = os.path.join(TEST_DATASET_DIR, class_name)
        if not os.path.isdir(class_dir):
            continue

        for file in os.listdir(class_dir):
            if not file.lower().endswith(VALID_EXTENSIONS):
                continue

            img_path = os.path.join(class_dir, file)
            image = Image.open(img_path).convert("RGB")

            img = image.resize(IMG_SIZE)
            img = np.array(img, dtype=np.float32)
            img = np.expand_dims(img, axis=0)
            img = preprocess_input(img)

            interpreter.set_tensor(input_details[0]["index"], img)
            interpreter.invoke()
            preds = interpreter.get_tensor(output_details[0]["index"])[0]

            if int(np.argmax(preds)) == label_index:
                correct += 1

            total += 1

    return (correct / total) if total > 0 else 0.0


MODEL_ACCURACY = evaluate_tflite_accuracy()

# -------------------------------------------------
# Load local images (optional)
# -------------------------------------------------
IMAGE_FILES = [
    f for f in os.listdir(SCRIPT_DIR)
    if f.lower().endswith(VALID_EXTENSIONS)
]

# -------------------------------------------------
# Core inference function
# -------------------------------------------------
def run_inference(image, source="Pasted Image"):
    img_resized = image.resize(IMG_SIZE)
    img_array = np.array(img_resized, dtype=np.float32)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)

    interpreter.set_tensor(input_details[0]["index"], img_array)
    interpreter.invoke()
    preds = interpreter.get_tensor(output_details[0]["index"])[0]

    top3_idx = np.argsort(preds)[-3:][::-1]

    top3_text = "\n".join([
        f"{CLASS_NAMES[i]}: {preds[i] * 100:.2f}%"
        for i in top3_idx
    ])

    display_img = image.resize((300, 300))
    tk_img = ImageTk.PhotoImage(display_img)
    image_label.config(image=tk_img)
    image_label.image = tk_img

    result_label.config(
        text=f"Source: {source}\n\n"
             f"Top Predictions:\n{top3_text}"
    )

    status_label.config(text="Ready")

# -------------------------------------------------
# Clipboard paste
# -------------------------------------------------
def paste_image(event=None):
    status_label.config(text="Pasting image...")
    root.update_idletasks()

    img = ImageGrab.grabclipboard()
    if isinstance(img, Image.Image):
        run_inference(img, source="Clipboard")
    else:
        status_label.config(text="Clipboard does not contain an image")

# -------------------------------------------------
# Random local image
# -------------------------------------------------
def classify_random_image():
    if not IMAGE_FILES:
        status_label.config(text="No local images found")
        return

    img_file = random.choice(IMAGE_FILES)
    img_path = os.path.join(SCRIPT_DIR, img_file)
    image = Image.open(img_path).convert("RGB")

    run_inference(image, source=img_file)

# -------------------------------------------------
# Build GUI
# -------------------------------------------------
root = tk.Tk()
root.title("Waste Classification (EfficientNetB2 · TFLite)")
root.geometry("430x620")
root.resizable(False, False)

root.bind("<Control-v>", paste_image)
root.bind("<Control-V>", paste_image)

accuracy_label = ttk.Label(
    root,
    text=f"Model Accuracy: {MODEL_ACCURACY * 100:.2f}%",
    font=("Segoe UI", 11, "bold")
)
accuracy_label.pack(pady=8)

title_label = ttk.Label(
    root,
    text="Waste Classification Demo",
    font=("Segoe UI", 16, "bold")
)
title_label.pack(pady=5)

hint_label = ttk.Label(
    root,
    text="Copy an image and press Ctrl+V",
    font=("Segoe UI", 10)
)
hint_label.pack()

image_label = ttk.Label(root)
image_label.pack(pady=10)

result_label = ttk.Label(
    root,
    text="Paste an image or use random test",
    font=("Segoe UI", 11),
    justify="center"
)
result_label.pack(pady=10)

button_frame = ttk.Frame(root)
button_frame.pack(pady=10)

ttk.Button(
    button_frame,
    text="Classify Random Local Image",
    command=classify_random_image
).grid(row=0, column=0, padx=5)

status_label = ttk.Label(root, text="Ready", font=("Segoe UI", 9))
status_label.pack(pady=5)

# -------------------------------------------------
# Start application
# -------------------------------------------------
root.mainloop()