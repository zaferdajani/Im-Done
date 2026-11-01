import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fetchWithTimeout } from '../src/http.mjs';

// A signal-aware transport avoids real upstream services and open sockets.
test('deadlines survive headers and preserve caller cancellation and options', async (t) => {
  let received;
  t.mock.method(globalThis, 'fetch', async (input, init) => {
    received = { input, ...init };
    return {
      json: () => new Promise((resolve, reject) => {
        if (init.signal.aborted) return reject(init.signal.reason);
        init.signal.addEventListener('abort', () => reject(init.signal.reason), { once: true });
      }),
    };
  });
  // AbortSignal.timeout uses an unref'd timer in Node.
  const keepAlive = setInterval(() => {}, 1000);
  try {
    const response = await fetchWithTimeout('https://example.test', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}',
      cf: { cacheTtl: 3600 },
    }, 20);
    assert.equal(received.method, 'POST');
    assert.equal(received.body, '{}');
    assert.deepEqual(received.cf, { cacheTtl: 3600 });
    assert.deepEqual(received.headers, { 'Content-Type': 'application/json' });
    await assert.rejects(response.json(), { name: 'TimeoutError' });

    const controller = new AbortController();
    const pending = await fetchWithTimeout('https://example.test', { signal: controller.signal });
    controller.abort();
    await assert.rejects(pending.json(), { name: 'AbortError' });
  } finally {
    clearInterval(keepAlive);
  }
});
