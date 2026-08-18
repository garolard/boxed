/**
 * Cover-scan proxy for the Boxed app.
 *
 * The app used to call OpenAI directly with a compile-time API key, which meant
 * the key shipped inside the binary and could be extracted. The app now POSTs
 * the raw photo here and this worker holds the key.
 *
 * Request:  POST /scan
 *           Content-Type: image/jpeg (or png/webp/heic/gif)
 *           body: the raw image bytes
 *           X-App-Token: <shared secret>   (only if APP_SHARED_SECRET is set)
 *
 * Response: 200 {"titles":[{"title":"Chrono Trigger","confidence":0.9}, ...]}
 *           4xx/5xx {"error":"..."}
 *
 * Bindings (wrangler secret put ...):
 *   OPENAI_API_KEY     required
 *   OPENAI_ORG_ID      optional
 *   APP_SHARED_SECRET  optional; when set, requests must present it
 */

const OPENAI_ENDPOINT = 'https://api.openai.com/v1/chat/completions';
const MODEL = 'gpt-5-nano';
const MAX_CANDIDATES = 6;

/** Hard cap on the upload. The app sends a 768px-longest-edge JPEG at q80,
 *  which lands well under this; anything bigger is not a real client. */
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
  'image/gif',
]);

const SYSTEM_PROMPT =
  'You identify videogames from photos of their physical media ' +
  '(box art, cover, cartridge or disc). Return up to ' +
  `${MAX_CANDIDATES} candidate official game titles ordered by ` +
  'likelihood, each with a confidence between 0 and 1. Use the ' +
  'visible logo, artwork, platform and any text. Prefer the ' +
  'canonical official title (omit edition/region suffixes unless ' +
  'printed prominently). If you cannot identify a specific game, ' +
  'return your best guesses from the readable text.';

export default {
  async fetch(request, env, _ctx) {
    if (request.method === 'OPTIONS') return cors(new Response(null, { status: 204 }));

    const url = new URL(request.url);
    if (url.pathname !== '/scan' && url.pathname !== '/') {
      return json({ error: 'Not found' }, 404);
    }
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405, { Allow: 'POST, OPTIONS' });
    }

    if (env.APP_SHARED_SECRET) {
      const presented = request.headers.get('X-App-Token') || '';
      if (!timingSafeEqual(presented, env.APP_SHARED_SECRET)) {
        return json({ error: 'Unauthorized' }, 401);
      }
    }
    if (!env.OPENAI_API_KEY) {
      console.error({ message: 'OPENAI_API_KEY binding missing' });
      return json({ error: 'Server not configured' }, 500);
    }

    // Content-Type carries the image type; strip any parameters.
    const mime = (request.headers.get('Content-Type') || '').split(';')[0].trim().toLowerCase();
    if (!ALLOWED_MIME.has(mime)) {
      return json({ error: `Unsupported Content-Type: ${mime || '(none)'}` }, 415);
    }

    const bytes = new Uint8Array(await request.arrayBuffer());
    if (bytes.byteLength === 0) return json({ error: 'Empty body' }, 400);
    if (bytes.byteLength > MAX_IMAGE_BYTES) return json({ error: 'Image too large' }, 413);

    const dataUri = `data:${mime};base64,${base64(bytes)}`;

    let upstream;
    try {
      upstream = await fetch(OPENAI_ENDPOINT, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          ...(env.OPENAI_ORG_ID ? { 'OpenAI-Organization': env.OPENAI_ORG_ID } : {}),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody(dataUri)),
      });
    } catch (err) {
      console.error({ message: 'OpenAI fetch failed', error: String(err) });
      return json({ error: 'Upstream request failed' }, 502);
    }

    if (!upstream.ok) {
      // Log the detail, but do not leak upstream bodies to the client.
      console.error({
        message: 'OpenAI returned an error',
        status: upstream.status,
        body: await upstream.text().catch(() => ''),
      });
      return json({ error: 'Recognition failed' }, upstream.status === 429 ? 429 : 502);
    }

    let titles;
    try {
      titles = parseTitles(await upstream.json());
    } catch (err) {
      console.error({ message: 'Could not parse OpenAI response', error: String(err) });
      return json({ error: 'Recognition failed' }, 502);
    }

    return json({ titles });
  },
};

function requestBody(dataUri) {
  return {
    model: MODEL,
    // Simple extraction task; keep reasoning minimal for a fast response.
    reasoning_effort: 'minimal',
    max_completion_tokens: 2000,
    response_format: {
      type: 'json_schema',
      json_schema: {
        name: 'game_titles',
        strict: true,
        schema: {
          type: 'object',
          additionalProperties: false,
          properties: {
            titles: {
              type: 'array',
              items: {
                type: 'object',
                additionalProperties: false,
                properties: {
                  title: { type: 'string' },
                  confidence: {
                    type: 'number',
                    description: 'Likelihood 0-1 that this is the game.',
                  },
                },
                required: ['title', 'confidence'],
              },
            },
          },
          required: ['titles'],
        },
      },
    },
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      {
        role: 'user',
        content: [
          { type: 'text', text: 'What videogame is this? List candidate titles.' },
          { type: 'image_url', image_url: { url: dataUri, detail: 'auto' } },
        ],
      },
    ],
  };
}

/**
 * Pulls the structured `{titles:[...]}` payload out of the chat completion and
 * normalises it: drops junk entries, de-duplicates case-insensitively, orders
 * by confidence and truncates. The app trusts this shape as-is.
 */
function parseTitles(completion) {
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || content.length === 0) return [];

  const parsed = JSON.parse(content);
  const raw = Array.isArray(parsed?.titles) ? parsed.titles : [];

  const seen = new Set();
  const out = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const title = typeof item.title === 'string' ? item.title.trim() : '';
    if (!title) continue;
    const key = title.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    const confidence = Number(item.confidence);
    out.push({ title, confidence: Number.isFinite(confidence) ? confidence : 0 });
  }
  out.sort((a, b) => b.confidence - a.confidence);
  return out.slice(0, MAX_CANDIDATES);
}

/** btoa() needs a binary string; chunked so a large image can't blow the stack. */
function base64(bytes) {
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

/** Constant-time compare, so the shared secret can't be probed byte by byte. */
function timingSafeEqual(a, b) {
  const ab = new TextEncoder().encode(a);
  const bb = new TextEncoder().encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
}

function json(body, status = 200, headers = {}) {
  return cors(
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json', ...headers },
    }),
  );
}

function cors(response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type, X-App-Token');
  response.headers.set('Access-Control-Max-Age', '86400');
  return response;
}
