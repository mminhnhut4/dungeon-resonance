import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request, ApiError, errorText } from '../src/api.js';

test('private request uses header, never URL, and preserves a conflict', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async (url, options) => {
    assert.equal(url, '/api/progress');
    assert.equal(options.headers.Authorization, 'Bearer synthetic-memory-token');
    assert.deepEqual(JSON.parse(options.body), { expectedRevision: 3 });
    return new Response(JSON.stringify({ title: 'revision_conflict' }), { status: 409 });
  };
  try { await assert.rejects(request('/progress', { method: 'PUT', token: 'synthetic-memory-token', body: { expectedRevision: 3 } }), e => e instanceof ApiError && e.status === 409); }
  finally { globalThis.fetch = original; }
});
test('timeout aborts pending network work with a recoverable message', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (_, options) => new Promise((_, reject) => options.signal.addEventListener('abort', () => reject(new DOMException('timeout', 'AbortError')), { once: true }));
  try { await assert.rejects(request('/me', { timeout: 10 }), e => /quá thời gian/.test(errorText(e))); }
  finally { globalThis.fetch = original; }
});
test('logout accepts empty 204 without a JSON parse', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async () => new Response(null, { status: 204 });
  try { assert.equal(await request('/auth/logout', { method: 'POST' }), null); }
  finally { globalThis.fetch = original; }
});
