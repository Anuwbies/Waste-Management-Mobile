/**
 * LLM Disposal-Guidance Service
 * ==============================
 * Calls the OpenRouter chat-completion API to generate structured,
 * JSON-only disposal guidance for a given waste type.
 *
 * Key design decisions:
 *  • Server-side only – API key never leaves the backend.
 *  • Deterministic temperature (0.25) for reproducible output.
 *  • 24-hour in-memory cache keyed on `wasteType` (case-insensitive).
 *  • Confidence gating – low-confidence items get a safe static response
 *    instead of an LLM call.
 *  • HTML-stripped output – guards against XSS in rich text.
 *  • Fallback to a static template if the LLM is unreachable.
 *
 * Env vars consumed (via `env.openRouter`):
 *   OPENROUTER_API_KEY   – required
 *   OPENROUTER_MODEL     – default "x-ai/grok-4-fast:free"
 *   SITE_URL / SITE_NAME – OpenRouter policy headers
 */

import https from "https";
import http from "http";
import { URL } from "url";
import { logger } from "../config/logger";
import { env, CNN_CONFIDENCE_THRESHOLD } from "../config/env";
import { stripHtml } from "../middleware/security";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface DisposalGuide {
  title: string;
  bin: string;
  steps: string[];
  doNot: string[];
  tips: string[];
  safety: string[];
}

interface CacheEntry {
  data: DisposalGuide;
  expiresAt: number;
}

// ─── Constants ───────────────────────────────────────────────────────────────

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const LLM_TIMEOUT_MS = 10_000; // 10 s hard timeout
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const LLM_TEMPERATURE = 0.25;

/** Maximum character length for any single output field from the LLM. */
const MAX_FIELD_LEN = 500;
/** Maximum character length for each array element (step / tip / etc.). */
const MAX_ITEM_LEN = 300;
/** Maximum number of items in any output array. */
const MAX_ARRAY_LEN = 10;

// ─── Allowlist ───────────────────────────────────────────────────────────────

/** Canonical waste types accepted by the LLM service. */
export const VALID_WASTE_TYPES = new Set([
  "plastic",
  "paper",
  "metal",
  "glass",
  "organic",
  "e-waste",
]);

/** Check whether a normalised waste type is in the allowlist. */
export const isValidWasteType = (type: string): boolean =>
  VALID_WASTE_TYPES.has(type.toLowerCase().trim());

// ─── In-memory cache ─────────────────────────────────────────────────────────

const cache = new Map<string, CacheEntry>();

/** Normalise waste type to a stable cache key. */
const cacheKey = (wasteType: string): string =>
  wasteType.toLowerCase().trim();

/** Purge expired entries (called lazily on every `get`). */
const purgeExpired = (): void => {
  const now = Date.now();
  for (const [key, entry] of cache) {
    if (entry.expiresAt <= now) cache.delete(key);
  }
};

// ─── Static fallback templates ───────────────────────────────────────────────

const FALLBACK_GUIDES: Record<string, DisposalGuide> = {
  plastic: {
    title: "How to dispose of Plastic properly",
    bin: "Blue",
    steps: [
      "Remove any food residue and rinse the container.",
      "Remove caps and lids – recycle them separately.",
      "Flatten bottles to save space.",
      "Check the recycling symbol (♻️) for the plastic type.",
      "Place in the blue recycling bin.",
    ],
    doNot: [
      "Do not put plastic bags in the recycling bin.",
      "Do not recycle styrofoam or polystyrene.",
    ],
    tips: [
      "Types 1 (PET) and 2 (HDPE) are the most widely recyclable.",
      "Recycling one plastic bottle saves enough energy to power a lightbulb for 3 hours.",
    ],
    safety: [],
  },
  paper: {
    title: "How to dispose of Paper properly",
    bin: "Blue",
    steps: [
      "Remove any plastic wrapping, sticky tape, or staples.",
      "Flatten cardboard boxes.",
      "Keep paper dry and clean.",
      "Place in the blue recycling bin.",
    ],
    doNot: [
      "Do not recycle wet or greasy paper (e.g. pizza boxes).",
      "Do not recycle wax-coated paper.",
    ],
    tips: [
      "Paper can be recycled 5–7 times before the fibers are too short.",
      "Shredded paper should be placed in a closed paper bag first.",
    ],
    safety: [],
  },
  metal: {
    title: "How to dispose of Metal properly",
    bin: "Blue",
    steps: [
      "Empty and rinse cans.",
      "Remove paper labels if possible.",
      "Crush cans to save space.",
      "Place in the blue recycling bin.",
    ],
    doNot: [
      "Do not recycle aerosol cans unless they are completely empty.",
      "Do not place paint cans in recycling – they are hazardous waste.",
    ],
    tips: [
      "Aluminium can be recycled infinitely without quality loss.",
      "Recycling aluminium uses 95 % less energy than making new aluminium.",
    ],
    safety: [],
  },
  glass: {
    title: "How to dispose of Glass properly",
    bin: "Green",
    steps: [
      "Remove lids and caps.",
      "Rinse bottles and jars.",
      "Remove any non-glass attachments.",
      "Place in the green glass recycling bin.",
    ],
    doNot: [
      "Do not put broken glass in regular recycling – wrap it safely.",
      "Do not recycle ceramics, mirrors, or window glass.",
    ],
    tips: [
      "Glass can be recycled indefinitely with no loss of quality.",
      "Separate by colour if your area requires it.",
    ],
    safety: ["Handle broken glass carefully – wear gloves."],
  },
  organic: {
    title: "How to dispose of Organic waste properly",
    bin: "Green/Brown",
    steps: [
      "Remove any plastic packaging.",
      "Place food scraps in the compost bin.",
      "Include fruit and vegetable peels.",
      "Coffee grounds and tea bags are compostable.",
    ],
    doNot: [
      "Do not put meat or dairy in a home compost bin.",
      "Do not compost diseased plants.",
    ],
    tips: [
      "Composting reduces methane emissions from landfills.",
      "Use finished compost to enrich your garden soil.",
    ],
    safety: [],
  },
  "e-waste": {
    title: "How to dispose of E-Waste properly",
    bin: "E-Waste Collection Point",
    steps: [
      "Back up any important data.",
      "Factory-reset devices to protect your privacy.",
      "Remove batteries if possible – recycle them separately.",
      "Take electronics to a certified e-waste collection point.",
    ],
    doNot: [
      "Never throw electronics in regular rubbish.",
      "Do not burn e-waste – it releases toxic fumes.",
    ],
    tips: [
      "Many retailers offer free e-waste take-back programmes.",
      "Consider donating working devices instead of disposing of them.",
    ],
    safety: [
      "Batteries can cause fires in landfills – always recycle them separately.",
      "E-waste may contain lead and mercury – handle with care.",
    ],
  },
};

/** Generic response for unrecognised or low-confidence items. */
const LOW_CONFIDENCE_GUIDE: DisposalGuide = {
  title: "Unable to Identify Item",
  bin: "Unknown",
  steps: ["Please retake the photo with better lighting."],
  doNot: [],
  tips: ["Make sure the object is clearly visible."],
  safety: [],
};

// ─── Prompt builder ──────────────────────────────────────────────────────────

const SYSTEM_PROMPT =
  "You are a recycling and environmental waste management expert.\n" +
  "Always respond in strict JSON format.\n" +
  "Provide clear, short, practical disposal steps.\n" +
  "Do not include markdown, explanations, or extra text.";

const buildUserPrompt = (
  wasteType: string,
  confidence: number,
  rawLabel?: string,
  topK?: string[],
): string => {
  const lines: string[] = [
    `Waste type: ${wasteType}`,
    `Confidence: ${confidence.toFixed(2)}`,
  ];
  if (rawLabel) lines.push(`Raw model label: ${rawLabel}`);
  if (topK && topK.length > 0) lines.push(`Other candidates: ${topK.join(", ")}`);
  lines.push(
    "",
    "Provide a JSON object with exactly these keys:",
    '  "title"  – short title, e.g. "How to dispose Plastic properly"',
    '  "bin"    – recommended bin colour or collection type',
    '  "steps"  – array of 3-5 short disposal steps',
    '  "doNot"  – array of common mistakes to avoid',
    '  "tips"   – array of practical advice',
    '  "safety" – array of safety notes (empty array if none)',
  );
  return lines.join("\n");
};

// ─── HTTP helper (Node built-ins, no external deps) ──────────────────────────

interface LlmRawResponse {
  choices?: { message?: { content?: string } }[];
  error?: { message?: string };
}

const postJson = (
  url: string,
  body: unknown,
  headers: Record<string, string>,
  timeoutMs: number,
): Promise<LlmRawResponse> =>
  new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const payload = JSON.stringify(body);
    const lib = parsed.protocol === "https:" ? https : http;

    const req = lib.request(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === "https:" ? 443 : 80),
        path: parsed.pathname + parsed.search,
        method: "POST",
        headers: {
          ...headers,
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload).toString(),
        },
        timeout: timeoutMs,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (c: Buffer) => chunks.push(c));
        res.on("end", () => {
          try {
            const text = Buffer.concat(chunks).toString("utf-8");
            resolve(JSON.parse(text) as LlmRawResponse);
          } catch {
            reject(new Error("LLM returned invalid JSON response"));
          }
        });
      },
    );

    req.on("timeout", () => {
      req.destroy();
      reject(new Error("LLM request timed out"));
    });
    req.on("error", (err) => reject(err));
    req.write(payload);
    req.end();
  });

// ─── Response sanitiser ──────────────────────────────────────────────────────

/**
 * Strip HTML tags from every string field in a DisposalGuide
 * to prevent stored-XSS if the LLM output is ever rendered in a WebView.
 */
const sanitiseGuide = (guide: DisposalGuide): DisposalGuide => ({
  title: stripHtml(guide.title),
  bin: stripHtml(guide.bin),
  steps: guide.steps.map(stripHtml),
  doNot: guide.doNot.map(stripHtml),
  tips: guide.tips.map(stripHtml),
  safety: guide.safety.map(stripHtml),
});

/**
 * Attempt to parse the LLM's content string into a valid DisposalGuide.
 * Returns `null` if the content is malformed.
 */
const parseLlmContent = (content: string): DisposalGuide | null => {
  try {
    // The model sometimes wraps JSON in ```json ... ``` fences – strip them.
    const cleaned = content
      .replace(/^```(?:json)?\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();
    const obj = JSON.parse(cleaned);

    // Validate mandatory keys
    if (
      typeof obj.title !== "string" ||
      typeof obj.bin !== "string" ||
      !Array.isArray(obj.steps)
    ) {
      return null;
    }

    // Truncate helper – caps individual strings and array sizes
    const cap = (s: unknown, max = MAX_ITEM_LEN): string =>
      String(s).slice(0, max);
    const capArr = (arr: unknown[], max = MAX_ARRAY_LEN): string[] =>
      arr.slice(0, max).map((v) => cap(v));

    return {
      title: cap(obj.title, MAX_FIELD_LEN),
      bin: cap(obj.bin, MAX_FIELD_LEN),
      steps: capArr(obj.steps as unknown[]),
      doNot: Array.isArray(obj.doNot) ? capArr(obj.doNot as unknown[]) : [],
      tips: Array.isArray(obj.tips) ? capArr(obj.tips as unknown[]) : [],
      safety: Array.isArray(obj.safety) ? capArr(obj.safety as unknown[]) : [],
    };
  } catch {
    return null;
  }
};

// ─── Public API ──────────────────────────────────────────────────────────────

export interface GenerateOptions {
  wasteType: string;
  confidence: number;
  rawLabel?: string;
  topK?: string[];
}

/**
 * Generate (or retrieve from cache) a structured disposal guide.
 *
 * 1. Low confidence → instant static response (no LLM call).
 * 2. Cache hit → return cached guide.
 * 3. LLM call → parse, sanitise, cache, return.
 * 4. LLM failure → fall back to static template.
 */
export const generateDisposalGuide = async (
  opts: GenerateOptions,
): Promise<DisposalGuide> => {
  const { wasteType, confidence, rawLabel, topK } = opts;
  const normType = wasteType.toLowerCase().trim();

  // ── 0. Allowlist gate ──────────────────────────────────────────────
  if (!VALID_WASTE_TYPES.has(normType)) {
    logger.warn(
      `[LLM] Rejected unknown waste type "${normType}" – returning fallback`,
    );
    return getFallback(normType);
  }

  // ── 1. Confidence gate ─────────────────────────────────────────────
  if (confidence < CNN_CONFIDENCE_THRESHOLD) {
    logger.info(
      `[LLM] Confidence ${confidence.toFixed(2)} below threshold – returning low-confidence guide`,
    );
    return LOW_CONFIDENCE_GUIDE;
  }

  // ── 2. Cache lookup ────────────────────────────────────────────────
  purgeExpired();
  const key = cacheKey(normType);
  const cached = cache.get(key);
  if (cached) {
    logger.debug(`[LLM] Cache hit for "${normType}"`);
    return cached.data;
  }

  // ── 3. Call LLM ────────────────────────────────────────────────────
  const apiKey = env.openRouter.apiKey;
  if (!apiKey) {
    logger.warn("[LLM] OPENROUTER_API_KEY not set – using static fallback");
    return getFallback(normType);
  }

  try {
    logger.info(`[LLM] Requesting disposal guide for "${normType}" …`);

    const llmBody = {
      model: env.openRouter.model,
      temperature: LLM_TEMPERATURE,
      max_tokens: 600,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: buildUserPrompt(normType, confidence, rawLabel, topK),
        },
      ],
    };

    const headers: Record<string, string> = {
      Authorization: `Bearer ${apiKey}`,
      "HTTP-Referer": env.openRouter.siteUrl,
      "X-Title": env.openRouter.siteName,
    };

    const raw = await postJson(OPENROUTER_URL, llmBody, headers, LLM_TIMEOUT_MS);

    // Handle API-level errors
    if (raw.error?.message) {
      logger.error(`[LLM] API error: ${raw.error.message}`);
      return getFallback(normType);
    }

    const content = raw.choices?.[0]?.message?.content;
    if (!content) {
      logger.warn("[LLM] Empty content in response – using fallback");
      return getFallback(normType);
    }

    const parsed = parseLlmContent(content);
    if (!parsed) {
      logger.warn("[LLM] Could not parse response as DisposalGuide – using fallback");
      logger.debug(`[LLM] Raw content: ${content.slice(0, 500)}`);
      return getFallback(normType);
    }

    const guide = sanitiseGuide(parsed);

    // ── 4. Cache the result ────────────────────────────────────────
    cache.set(key, { data: guide, expiresAt: Date.now() + CACHE_TTL_MS });
    logger.info(`[LLM] Guide for "${normType}" cached (TTL 24 h)`);

    return guide;
  } catch (err) {
    // Never expose raw LLM errors to the client
    const msg = err instanceof Error ? err.message : String(err);
    logger.error(`[LLM] Request failed: ${msg}`);
    return getFallback(normType);
  }
};

// ─── Fallback helper ─────────────────────────────────────────────────────────

const getFallback = (normType: string): DisposalGuide => {
  const guide = FALLBACK_GUIDES[normType];
  if (guide) {
    logger.debug(`[LLM] Using static fallback for "${normType}"`);
    return guide;
  }

  logger.debug(`[LLM] No static fallback for "${normType}" – returning generic guide`);
  return {
    title: `How to dispose of ${normType} properly`,
    bin: "General Waste Bin",
    steps: [
      "Check local guidelines for this item.",
      "If recyclable, clean and dry before disposal.",
      "Place in the appropriate bin.",
    ],
    doNot: ["When in doubt, check with local waste management."],
    tips: ["Consider whether the item can be reused or donated."],
    safety: [],
  };
};

// ─── Cache management (exposed for tests / admin) ────────────────────────────

/** Clear the entire disposal-guide cache. */
export const clearCache = (): void => {
  cache.clear();
  logger.info("[LLM] Cache cleared");
};

/** Return current cache size (for health checks). */
export const cacheSize = (): number => cache.size;
