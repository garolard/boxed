# boxed-cover-scan worker

Holds the OpenAI key for the app's cover scan. The app posts a photo, the worker
calls `gpt-5-nano` vision and returns candidate game titles.

## Deploy

```bash
cd worker
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put OPENAI_ORG_ID       # optional
npx wrangler secret put APP_SHARED_SECRET   # optional but recommended
npx wrangler deploy
```

Local: `npx wrangler dev` (secrets go in a gitignored `.dev.vars`).

## API

`POST /scan` with the raw image bytes and a `Content-Type` of `image/jpeg`,
`image/png`, `image/webp`, `image/heic`, `image/heif` or `image/gif`.
Max 5 MB. Send `X-App-Token` if `APP_SHARED_SECRET` is set.

```json
{ "titles": [ { "title": "Chrono Trigger", "confidence": 0.91 } ] }
```

Already de-duplicated, sorted by confidence, capped at 6. Errors are
`{ "error": "..." }`; upstream OpenAI bodies are logged, never returned.

```bash
curl -X POST https://<worker>.workers.dev/scan \
  -H 'Content-Type: image/jpeg' -H 'X-App-Token: ...' \
  --data-binary @cover.jpg
```

## Note on abuse

`APP_SHARED_SECRET` is extractable from the app binary — it raises the bar but
is not real authentication. It stops casual scraping of the endpoint; the real
protections are the Cloudflare rate limit on the route and the app's existing
per-user scan quota in Firestore. If abuse becomes a problem, verify a Firebase
App Check / anonymous-auth token here instead.
