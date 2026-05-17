import {
  createExecutionContext,
  env,
  fetchMock,
  waitOnExecutionContext,
} from 'cloudflare:test';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';

import worker from '../src/index';

const SAMPLE_PV_JSON = JSON.stringify({
  inputs: {},
  outputs: { hourly: [] },
});

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function dispatch(url: string, init?: RequestInit): Promise<Response> {
  const request = new Request(url, init);
  const ctx = createExecutionContext();
  // The worker's signature is (request, env); pass ctx through the awaited
  // execution context helper instead so vitest-pool-workers can drain any
  // background work the handler scheduled.
  const response = await worker.fetch(request, env);
  await waitOnExecutionContext(ctx);
  return response;
}

function stubPvgis(times = 1, body: string = SAMPLE_PV_JSON, status = 200): void {
  fetchMock
    .get('https://re.jrc.ec.europa.eu')
    .intercept({ path: (p) => p.startsWith('/api/v5_3/seriescalc') })
    .reply(status, body, { headers: { 'content-type': 'application/json' } })
    .times(times);
}

describe('PVGIS caching proxy', () => {
  it('returns MISS then HIT for the same canonical params', async () => {
    stubPvgis(1);
    const url =
      'https://proxy.test/?lat=52.41&lon=7.976&angle=30&aspect=0' +
      '&peakpower=5&loss=14&pvcalculation=1' +
      '&startyear=2022&endyear=2022&usehorizon=1';

    const first = await dispatch(url);
    expect(first.status).toBe(200);
    expect(first.headers.get('X-Cache')).toBe('MISS');

    const second = await dispatch(url);
    expect(second.status).toBe(200);
    expect(second.headers.get('X-Cache')).toBe('HIT');
  });

  it('keys horizontal-irradiance and PV-mode requests separately', async () => {
    // Two distinct upstream fetches because the cache keys must differ.
    stubPvgis(2);

    const pvMode = await dispatch(
      'https://proxy.test/?lat=52.41&lon=7.976&angle=30&aspect=0' +
        '&peakpower=5&loss=14&pvcalculation=1' +
        '&startyear=2022&endyear=2022&usehorizon=1',
    );
    const horizontal = await dispatch(
      'https://proxy.test/?lat=52.41&lon=7.976&angle=0&aspect=0' +
        '&components=1&pvcalculation=0' +
        '&startyear=2022&endyear=2022&usehorizon=1',
    );

    expect(pvMode.headers.get('X-Cache')).toBe('MISS');
    expect(horizontal.headers.get('X-Cache')).toBe('MISS');
    expect(pvMode.headers.get('X-Cache-Key')).not.toEqual(
      horizontal.headers.get('X-Cache-Key'),
    );
  });

  it('produces the same cache key regardless of query param order', async () => {
    stubPvgis(1);
    const ordered = await dispatch(
      'https://proxy.test/?angle=30&aspect=0&endyear=2022&lat=52.41' +
        '&lon=7.976&loss=14&peakpower=5&pvcalculation=1' +
        '&startyear=2022&usehorizon=1',
    );
    const shuffled = await dispatch(
      'https://proxy.test/?usehorizon=1&startyear=2022&pvcalculation=1' +
        '&peakpower=5&loss=14&lon=7.976&lat=52.41&endyear=2022' +
        '&aspect=0&angle=30',
    );

    expect(ordered.headers.get('X-Cache')).toBe('MISS');
    expect(shuffled.headers.get('X-Cache')).toBe('HIT');
    expect(ordered.headers.get('X-Cache-Key')).toEqual(
      shuffled.headers.get('X-Cache-Key'),
    );
  });

  it('answers OPTIONS preflight with 204 and CORS headers', async () => {
    const response = await dispatch('https://proxy.test/', { method: 'OPTIONS' });
    expect(response.status).toBe(204);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('GET');
  });

  it('rejects non-GET methods with 405', async () => {
    const response = await dispatch('https://proxy.test/', { method: 'POST' });
    expect(response.status).toBe(405);
    expect(response.headers.get('Allow')).toContain('GET');
  });

  it('propagates upstream 4xx without caching', async () => {
    stubPvgis(2, JSON.stringify({ message: 'outside coverage' }), 400);

    const first = await dispatch(
      'https://proxy.test/?lat=99.0&lon=0.0&angle=30&aspect=0' +
        '&peakpower=5&loss=14&pvcalculation=1' +
        '&startyear=2022&endyear=2022&usehorizon=1',
    );
    expect(first.status).toBe(400);
    expect(first.headers.get('X-Cache')).toBe('MISS');

    // Re-running the same request hits upstream again — error was not cached.
    const second = await dispatch(
      'https://proxy.test/?lat=99.0&lon=0.0&angle=30&aspect=0' +
        '&peakpower=5&loss=14&pvcalculation=1' +
        '&startyear=2022&endyear=2022&usehorizon=1',
    );
    expect(second.status).toBe(400);
    expect(second.headers.get('X-Cache')).toBe('MISS');
  });
});
