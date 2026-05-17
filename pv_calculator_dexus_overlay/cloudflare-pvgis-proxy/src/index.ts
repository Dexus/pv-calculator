/**
 * Cloudflare Worker — PVGIS caching proxy
 *
 * Accepts the same query parameters as the public PVGIS seriescalc endpoint.
 * Computes a SHA-256 hash of the canonical parameters, checks R2 for a
 * cached response, and only calls the real PVGIS API on a cache miss.
 *
 * Response headers:
 *   X-Cache: HIT | MISS
 *   X-Cache-Key: <hex SHA-256 of canonical params>
 *
 * Deploy:
 *   wrangler deploy
 *
 * Flutter integration: pass the Worker URL as PVGIS_PROXY at build time:
 *   flutter build web --dart-define=PVGIS_PROXY=https://<worker>.workers.dev
 */

import type { Env } from './types';

const PVGIS_UPSTREAM = 'https://re.jrc.ec.europa.eu/api/v5_3/seriescalc';

// Parameters that define a unique PVGIS result. Sorted alphabetically before
// hashing so equivalent requests always yield the same key regardless of the
// order the Flutter client sends them.
const CACHE_PARAMS = [
  'angle',
  'aspect',
  'components',
  'endyear',
  'lat',
  'lon',
  'loss',
  'mountingplace',
  'outputformat',
  'peakpower',
  'pvcalculation',
  'raddatabase',
  'startyear',
  'usehorizon',
] as const;

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Accept, Content-Type',
  // Required so Flutter web (which runs inside a browser CORS sandbox) can
  // read these response headers. Without Expose-Headers the browser strips
  // them and the X-Cache badge in the app always shows "unknown".
  'Access-Control-Expose-Headers': 'X-Cache, X-Cache-Key',
};

async function sha256Hex(input: string): Promise<string> {
  const encoded = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', encoded);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/** Builds a stable canonical query string from the recognised cache params.
 *
 *  `outputformat` is normalised to `json` so the cache key reflects the actual
 *  upstream request, not whatever the client happened to send. `pvcalculation`
 *  is no longer forced — both PV-power mode (`pvcalculation=1`, requires
 *  `peakpower`+`loss`) and horizontal-irradiance mode (`pvcalculation=0`,
 *  paired with `components=1`) are legitimate; the value the client sends is
 *  preserved in the cache key so the two modes don't alias to the same R2
 *  object.
 */
function canonicalParams(url: URL): string {
  const ENFORCED: Partial<Record<(typeof CACHE_PARAMS)[number], string>> = {
    outputformat: 'json',
  };
  const pairs: [string, string][] = [];
  for (const key of CACHE_PARAMS) {
    const forced = ENFORCED[key];
    if (forced !== undefined) {
      pairs.push([key, forced]);
      continue;
    }
    const value = url.searchParams.get(key);
    if (value !== null && value !== '') {
      pairs.push([key, value]);
    }
  }
  // Already sorted because CACHE_PARAMS is declared in alphabetical order,
  // but sort explicitly to be safe against future edits.
  pairs.sort((a, b) => a[0].localeCompare(b[0]));
  return new URLSearchParams(pairs).toString();
}

/** Builds the upstream PVGIS URL, forwarding all incoming query params and
 *  forcing outputformat=json. */
function buildUpstreamUrl(incomingUrl: URL): URL {
  const upstream = new URL(PVGIS_UPSTREAM);
  // Copy all params from the incoming request, then enforce required fields.
  incomingUrl.searchParams.forEach((value, key) => {
    upstream.searchParams.set(key, value);
  });
  upstream.searchParams.set('outputformat', 'json');
  return upstream;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method !== 'GET') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: { ...CORS_HEADERS, Allow: 'GET, OPTIONS' },
      });
    }

    const url = new URL(request.url);
    const canonical = canonicalParams(url);
    const hash = await sha256Hex(canonical);
    const r2Key = `pvgis/${hash}.json`;

    // --- Cache hit ---
    const cached = await env.PVGIS_CACHE.get(r2Key);
    if (cached !== null) {
      const body = await cached.text();
      return new Response(body, {
        status: 200,
        headers: {
          ...CORS_HEADERS,
          'Content-Type': 'application/json',
          'X-Cache': 'HIT',
          'X-Cache-Key': hash,
        },
      });
    }

    // --- Cache miss: fetch from PVGIS ---
    const upstreamUrl = buildUpstreamUrl(url);
    let pvgisResponse: Response;
    try {
      pvgisResponse = await fetch(upstreamUrl.toString(), {
        headers: { Accept: 'application/json' },
      });
    } catch (err) {
      return new Response(
        JSON.stringify({ error: 'PVGIS upstream unreachable', detail: String(err) }),
        {
          status: 502,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        },
      );
    }

    const responseBody = await pvgisResponse.text();

    // Only cache successful responses to avoid storing PVGIS error messages.
    if (pvgisResponse.ok) {
      await env.PVGIS_CACHE.put(r2Key, responseBody, {
        httpMetadata: { contentType: 'application/json' },
        customMetadata: {
          canonical,
          fetchedAt: new Date().toISOString(),
        },
      });
    }

    return new Response(responseBody, {
      status: pvgisResponse.status,
      headers: {
        ...CORS_HEADERS,
        'Content-Type': 'application/json',
        'X-Cache': 'MISS',
        'X-Cache-Key': hash,
      },
    });
  },
} satisfies ExportedHandler<Env>;
