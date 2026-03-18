"""
Waste Classification Inference Service
=======================================
FastAPI microservice that loads the Keras EfficientNetB2 model once at startup
and exposes an HTTP classification endpoint for the backend.

Run:
    uvicorn inference_service:app --host 0.0.0.0 --port 8000

CLI test:
    python inference_service.py --test-image path/to/image.jpg
"""

import os
import sys
import json
import argparse
import logging
import hashlib
from io import BytesIO
from typing import List

import numpy as np
from PIL import Image

# --- Logging --------------------------------------------------------------- #
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("inference_service")

# --- Configuration --------------------------------------------------------- #
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(SCRIPT_DIR, "new_best_efficientnetb2_calibrated.keras")
CONFIG_PATH = os.path.join(SCRIPT_DIR, "waste_classifier_config.json")

# Load configuration for hyperparams like temperature
with open(CONFIG_PATH, "r") as f:
    _config = json.load(f)

IMG_SIZE = tuple(_config.get("img_size", [260, 260]))
TEMPERATURE = float(_config.get("temperature", 1.0))
MODEL_VERSION = "new_best_efficientnetb2_calibrated.keras"

# The 9-class label order MUST match training order exactly.
CLASS_NAMES: List[str] = [
    "E-waste",
    "Automobile",
    "Battery",
    "Glass",
    "Light Bulb",
    "Metal",
    "Organic",
    "Paper",
    "Plastic",
]

# Mapping from model raw labels → backend canonical waste types.
#
# Backend canonical types: plastic, paper, metal, glass, organic, e-waste
#
# Mapping rationale:
#   Plastic     → plastic       (direct)
#   Paper       → paper         (direct)
#   Metal       → metal         (direct)
#   Glass       → glass         (direct)
#   Organic     → organic       (direct)
#   E-waste     → e-waste       (direct — electronic waste)
#   Battery     → e-waste       (batteries are hazardous e-waste)
#   Light Bulb  → e-waste       (contains mercury, treated as e-waste)
#   Automobile  → metal         (primarily metal components; could also be
#                                "unknown" but metal recycling applies)
LABEL_TO_CANONICAL = {
    "Plastic":    "plastic",
    "Paper":      "paper",
    "Metal":      "metal",
    "Glass":      "glass",
    "Organic":    "organic",
    "E-waste":    "e-waste",
    "Battery":    "e-waste",
    "Light Bulb": "e-waste",
    "Automobile":  "metal",
}

# --- Keras Model --------------------------------------------------- #
import tensorflow as tf

_model: tf.keras.Model | None = None


def _load_model() -> None:
    """Load the Keras model into a module-level variable."""
    global _model

    if not os.path.isfile(MODEL_PATH):
        raise FileNotFoundError(f"Keras model not found at {MODEL_PATH}")

    _model = tf.keras.models.load_model(MODEL_PATH)
    logger.info("Keras model loaded: %s", MODEL_PATH)


def _ensure_model() -> None:
    if _model is None:
        _load_model()


# --- Pre-processing (must match training) --------------------------------- #
# EfficientNet TFLite models typically include rescaling or expect [0, 255] float
# We will skip the heavy Keras import for preprocessing.
def preprocess(image: Image.Image) -> np.ndarray:
    """Resize, convert to float32, and prepare for inference."""
    # Using BILINEAR is significantly faster than LANCZOS and sufficient for 260x260
    img = image.convert("RGB").resize(IMG_SIZE, Image.Resampling.BILINEAR)
    arr = np.array(img, dtype=np.float32)
    arr = np.expand_dims(arr, axis=0)      # (1, 260, 260, 3)
    # EfficientNet V1 models in Keras/TFLite usually handle scaling internally 
    # or expect pixels in range [0, 255].
    return arr


def softmax_with_temperature(logits, temperature=1.0):
    logits = np.asarray(logits, dtype=np.float32)
    scaled = logits / temperature
    exp = np.exp(scaled - np.max(scaled))
    return exp / np.sum(exp)


# --- Inference ------------------------------------------------------------- #
def classify(image: Image.Image, top_k: int = 5) -> dict:
    """
    Run classification on a PIL Image.

    Returns dict with:
        wasteType   – canonical backend label
        confidence  – float 0..1
        topK        – list of {label, canonicalLabel, score}
        rawLabel    – original model class name
        modelVersion
        inputSize
    """
    _ensure_model()

    arr = preprocess(image)
    logits = _model.predict(arr, verbose=0)[0]
    preds = softmax_with_temperature(logits, temperature=TEMPERATURE)

    # Ensure predictions are proper probabilities
    preds = preds.astype(float)

    # Top-K indices (descending by score)
    k = min(top_k, len(CLASS_NAMES))
    top_indices = np.argsort(preds)[-k:][::-1]

    top_k_list = []
    for idx in top_indices:
        raw = CLASS_NAMES[idx]
        top_k_list.append({
            "label": raw,
            "canonicalLabel": LABEL_TO_CANONICAL.get(raw, "unknown"),
            "score": round(float(preds[idx]), 6),
        })

    best_idx = int(top_indices[0])
    raw_label = CLASS_NAMES[best_idx]
    canonical = LABEL_TO_CANONICAL.get(raw_label, "unknown")
    confidence = float(preds[best_idx])

    return {
        "wasteType": canonical,
        "confidence": round(confidence, 6),
        "topK": top_k_list,
        "rawLabel": raw_label,
        "modelVersion": MODEL_VERSION,
        "inputSize": list(IMG_SIZE),
    }


# =========================================================================== #
# FastAPI Application
# =========================================================================== #
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse

app = FastAPI(
    title="Waste Classification Service",
    version="1.0.0",
    description="Keras EfficientNetB2 inference microservice",
)


@app.on_event("startup")
async def startup_event():
    """Pre-load model on server start so first request is fast."""
    try:
        _load_model()
        logger.info("Model loaded at startup — ready to serve")
    except Exception as exc:
        logger.error("Failed to load model at startup: %s", exc)
        # Don't crash — let health endpoint report the issue.


@app.get("/health")
async def health():
    """Health check — reports model status."""
    model_loaded = _model is not None
    return {
        "status": "ok" if model_loaded else "degraded",
        "modelLoaded": model_loaded,
        "modelVersion": MODEL_VERSION,
        "classCount": len(CLASS_NAMES),
        "inputSize": list(IMG_SIZE),
    }


@app.post("/classify")
async def classify_endpoint(image: UploadFile = File(...)):
    """
    Classify an uploaded waste image.

    Accepts: multipart/form-data with field name `image`
    Returns: JSON with wasteType, confidence, topK, rawLabel, etc.
    """
    # Validate content type
    content_type = image.content_type or ""
    allowed = {"image/jpeg", "image/png", "image/webp", "image/heic"}
    if content_type not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image type: {content_type}. Allowed: {', '.join(sorted(allowed))}",
        )

    try:
        raw_bytes = await image.read()
        pil_image = Image.open(BytesIO(raw_bytes)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Cannot read image: {exc}")

    try:
        result = classify(pil_image)
    except Exception as exc:
        logger.exception("Inference failed")
        raise HTTPException(status_code=500, detail=f"Inference error: {exc}")

    logger.info(
        "Classified → %s (%.2f%%) raw=%s",
        result["wasteType"],
        result["confidence"] * 100,
        result["rawLabel"],
    )
    return JSONResponse(content=result)


# =========================================================================== #
# Perceptual Hashing (anti-cheat: near-duplicate detection)
# =========================================================================== #

PHASH_SIZE = 8  # produces a 64-bit hash


def _compute_phash(image: Image.Image, hash_size: int = PHASH_SIZE) -> str:
    """
    Compute a perceptual hash (pHash) using DCT.

    Steps:
      1. Convert to greyscale and resize to (hash_size*4 x hash_size*4).
      2. Compute 2-D DCT.
      3. Keep the top-left hash_size×hash_size low-frequency block.
      4. Median-threshold to produce a binary string → hex.

    Two images with a small Hamming distance between their pHash values
    are visually very similar, even after crops, compression, or rescaling.
    """
    grey = image.convert("L").resize(
        (hash_size * 4, hash_size * 4), Image.Resampling.BILINEAR
    )
    pixels = np.array(grey, dtype=np.float64)

    # 2-D DCT via scipy if available, else manual rows+cols DCT
    try:
        from scipy.fftpack import dct

        dct_full = dct(dct(pixels, axis=0, norm="ortho"), axis=1, norm="ortho")
    except ImportError:
        # Fallback: use numpy FFT-based approximation
        dct_full = np.real(np.fft.fft2(pixels))

    low_freq = dct_full[:hash_size, :hash_size]
    median = np.median(low_freq)
    bits = (low_freq > median).flatten()
    # Pack bits into hex string
    hash_int = 0
    for bit in bits:
        hash_int = (hash_int << 1) | int(bit)
    return format(hash_int, f"0{hash_size * hash_size // 4}x")


def _compute_sha256(raw_bytes: bytes) -> str:
    """Compute SHA-256 hex digest of raw image bytes."""
    return hashlib.sha256(raw_bytes).hexdigest()


def hamming_distance(h1: str, h2: str) -> int:
    """Hamming distance between two hex-encoded hashes of equal length."""
    if len(h1) != len(h2):
        raise ValueError("Hashes must be the same length")
    val = int(h1, 16) ^ int(h2, 16)
    return bin(val).count("1")


@app.post("/phash")
async def phash_endpoint(image: UploadFile = File(...)):
    """
    Compute perceptual hash + SHA-256 of an uploaded image.

    Returns:
        phash      – hex perceptual hash (64-bit by default)
        sha256     – hex SHA-256 of raw bytes
        hashSize   – the pHash grid size used
    """
    content_type = image.content_type or ""
    allowed = {"image/jpeg", "image/png", "image/webp", "image/heic"}
    if content_type not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image type: {content_type}. Allowed: {', '.join(sorted(allowed))}",
        )

    try:
        raw_bytes = await image.read()
        pil_image = Image.open(BytesIO(raw_bytes)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Cannot read image: {exc}")

    phash_hex = _compute_phash(pil_image)
    sha256_hex = _compute_sha256(raw_bytes)

    logger.info("pHash=%s  sha256=%s…", phash_hex, sha256_hex[:16])
    return JSONResponse(
        content={
            "phash": phash_hex,
            "sha256": sha256_hex,
            "hashSize": PHASH_SIZE,
        }
    )


@app.post("/phash/compare")
async def phash_compare_endpoint(hash1: str, hash2: str):
    """
    Compare two perceptual hashes and return the Hamming distance.

    Body (JSON): { "hash1": "<hex>", "hash2": "<hex>" }
    Returns:
        distance  – integer Hamming distance
        similar   – bool (distance <= 10 is typically "same image")
    """
    if not hash1 or not hash2:
        raise HTTPException(
            status_code=400, detail="Both hash1 and hash2 are required"
        )
    try:
        dist = hamming_distance(hash1, hash2)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    return JSONResponse(
        content={
            "hash1": hash1,
            "hash2": hash2,
            "distance": dist,
            "similar": dist <= 10,
        }
    )


# =========================================================================== #
# CLI test mode
# =========================================================================== #
def _cli_test(image_path: str) -> None:
    """Quick CLI test — prints JSON result to stdout."""
    if not os.path.isfile(image_path):
        print(f"ERROR: File not found: {image_path}", file=sys.stderr)
        sys.exit(1)

    _load_model()
    img = Image.open(image_path).convert("RGB")
    result = classify(img)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Waste Classification Inference")
    parser.add_argument(
        "--test-image",
        type=str,
        help="Path to an image file for CLI testing",
    )
    parser.add_argument(
        "--host", type=str, default="0.0.0.0", help="Host to bind (default 0.0.0.0)"
    )
    parser.add_argument(
        "--port", type=int, default=8000, help="Port to bind (default 8000)"
    )
    args = parser.parse_args()

    if args.test_image:
        _cli_test(args.test_image)
    else:
        import uvicorn
        uvicorn.run(app, host=args.host, port=args.port)
