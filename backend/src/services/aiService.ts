/**
 * AI Classification Service Client
 * =================================
 * Sends uploaded images to the Python FastAPI inference microservice
 * and returns typed classification results.
 *
 * Env:  AI_SERVICE_URL  (default http://127.0.0.1:8000)
 */

import fs from "fs";
import path from "path";
import http from "http";
import https from "https";

// -------------------------------------------------------------------------- //
// Types
// -------------------------------------------------------------------------- //
export interface TopKPrediction {
  label: string;
  canonicalLabel: string;
  score: number;
}

export interface AiClassificationResult {
  wasteType: string; // canonical: plastic|paper|metal|glass|organic|e-waste|unknown
  confidence: number; // 0..1
  topK: TopKPrediction[];
  rawLabel: string; // original model class name
  modelVersion: string;
  inputSize: number[];
}

export interface AiHealthResult {
  status: string;
  modelLoaded: boolean;
  modelVersion: string;
  classCount: number;
  inputSize: number[];
}

// -------------------------------------------------------------------------- //
// Helpers
// -------------------------------------------------------------------------- //
const AI_SERVICE_URL = (): string =>
  process.env.AI_SERVICE_URL?.replace(/\/+$/, "") || "http://127.0.0.1:8000";

const AI_TIMEOUT_MS = 30_000; // 30 s – TFLite on CPU can be slow for large images

/** Map file extension to MIME type for the multipart boundary */
const mimeFromExt = (filePath: string): string => {
  const ext = path.extname(filePath).toLowerCase();
  const map: Record<string, string> = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
  };
  return map[ext] || "application/octet-stream";
};

/**
 * Low-level multipart POST using only Node built-ins (no axios / node-fetch).
 * Sends exactly one file field named "image".
 */
const postMultipart = (
  url: string,
  filePath: string,
  timeoutMs: number
): Promise<{ status: number; body: string }> => {
  return new Promise((resolve, reject) => {
    const boundary = `----NodeFormBoundary${Date.now()}`;
    const fileName = path.basename(filePath);
    const mime = mimeFromExt(filePath);
    const fileStream = fs.createReadStream(filePath);
    const fileSize = fs.statSync(filePath).size;

    // Build multipart header / footer buffers
    const header = Buffer.from(
      `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="image"; filename="${fileName}"\r\n` +
        `Content-Type: ${mime}\r\n\r\n`
    );
    const footer = Buffer.from(`\r\n--${boundary}--\r\n`);

    const contentLength = header.length + fileSize + footer.length;

    const parsed = new URL(url);
    const transport = parsed.protocol === "https:" ? https : http;

    const options: http.RequestOptions = {
      method: "POST",
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === "https:" ? 443 : 80),
      path: parsed.pathname + parsed.search,
      headers: {
        "Content-Type": `multipart/form-data; boundary=${boundary}`,
        "Content-Length": contentLength,
      },
      timeout: timeoutMs,
    };

    const req = transport.request(options, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => {
        resolve({
          status: res.statusCode ?? 500,
          body: Buffer.concat(chunks).toString("utf-8"),
        });
      });
    });

    req.on("timeout", () => {
      req.destroy();
      reject(new Error(`AI service timeout after ${timeoutMs}ms`));
    });
    req.on("error", reject);

    // Stream: header → file bytes → footer
    req.write(header);
    fileStream.on("data", (chunk: string | Buffer) => {
      req.write(chunk);
    });
    fileStream.on("end", () => {
      req.write(footer);
      req.end();
    });
    fileStream.on("error", reject);
  });
};

/**
 * Simple GET request returning body string.
 */
const getRequest = (
  url: string,
  timeoutMs: number
): Promise<{ status: number; body: string }> => {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const transport = parsed.protocol === "https:" ? https : http;

    const req = transport.get(url, { timeout: timeoutMs }, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => {
        resolve({
          status: res.statusCode ?? 500,
          body: Buffer.concat(chunks).toString("utf-8"),
        });
      });
    });

    req.on("timeout", () => {
      req.destroy();
      reject(new Error(`AI health check timeout after ${timeoutMs}ms`));
    });
    req.on("error", reject);
  });
};

// -------------------------------------------------------------------------- //
// Public API
// -------------------------------------------------------------------------- //

/**
 * Send an image file to the AI service for classification.
 *
 * @param imagePath  Absolute path to the uploaded image on disk.
 * @returns          Parsed classification result.
 * @throws           On network error, timeout, or non-200 response.
 */
export const classifyImage = async (
  imagePath: string
): Promise<AiClassificationResult> => {
  const url = `${AI_SERVICE_URL()}/classify`;

  console.log(`[aiService] Classifying image: ${path.basename(imagePath)}`);
  console.log(`[aiService] POST ${url}`);

  const { status, body } = await postMultipart(url, imagePath, AI_TIMEOUT_MS);

  if (status !== 200) {
    console.error(`[aiService] AI service returned HTTP ${status}: ${body}`);
    throw new Error(`AI classification failed (HTTP ${status}): ${body}`);
  }

  const result: AiClassificationResult = JSON.parse(body);

  console.log(
    `[aiService] Result: wasteType=${result.wasteType} ` +
      `confidence=${(result.confidence * 100).toFixed(1)}% ` +
      `raw=${result.rawLabel}`
  );

  return result;
};

/**
 * Check whether the AI inference service is reachable and model is loaded.
 */
export const getAiHealth = async (): Promise<AiHealthResult> => {
  const url = `${AI_SERVICE_URL()}/health`;
  const { status, body } = await getRequest(url, 5_000);

  if (status !== 200) {
    throw new Error(`AI health check failed (HTTP ${status})`);
  }

  return JSON.parse(body) as AiHealthResult;
};

/**
 * Quick boolean check: is the AI service up and model loaded?
 */
export const isAiServiceHealthy = async (): Promise<boolean> => {
  try {
    const health = await getAiHealth();
    return health.modelLoaded === true;
  } catch {
    return false;
  }
};
