import time
import os
from PIL import Image
from inference_service import classify, _load_model, _compute_phash

# Setup
_load_model()
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
UPLOAD_DIR = os.path.join(ROOT_DIR, "backend", "uploads")

test_images = [
    os.path.join(UPLOAD_DIR, "waste-1770822556506-621177501.jpg"),
    os.path.join(UPLOAD_DIR, "waste-1771390778859-907581982.jpg"),
    os.path.join(UPLOAD_DIR, "waste-1770819118003-436823859.png")
]

print(f"{'Test Case':<45} | {'Result (sec)':<15} | {'Identified Bottleneck'}")
print("-" * 85)

last_img = None
for img_path in test_images:
    if not os.path.exists(img_path):
        print(f"File not found: {img_path}")
        continue
    
    img = Image.open(img_path).convert("RGB")
    last_img = img
    
    start = time.time()
    # run your function here
    result = classify(img)
    end = time.time()
    
    duration = end - start
    
    # Simple bottleneck identification logic
    bottleneck = "None"
    if duration > 0.5:
        bottleneck = "Model inference latency"
    elif duration > 0.2:
        bottleneck = "Preprocessing overhead"
    
    print(f"{os.path.basename(img_path):<45} | {duration:<15.4f} | {bottleneck}")

# Run classification one more time to measure "Contract function" (simulated via phash)
if last_img:
    start = time.time()
    _compute_phash(last_img)
    end = time.time()
    duration = end - start
    print(f"{'pHash computation':<45} | {duration:<15.4f} | {'DCT computation'}")
else:
    print("No images found to run pHash test.")
