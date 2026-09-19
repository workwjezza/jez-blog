import test from 'node:test';
import assert from 'node:assert/strict';
import { publicEntries } from '../src/lib/content-policy.ts';
import { writingSchema, experimentSchema } from '../src/lib/schemas.ts';

test('empty collections remain empty', () => {
  assert.deepEqual(publicEntries([]), []);
});

test('draft policy fails closed', () => {
  const entries = [true, undefined, false].map((draft, i) => ({ id: String(i), data: { draft } }));
  assert.deepEqual(publicEntries(entries).map(e => e.id), ['2']);
  assert.equal(writingSchema.parse({ title: 'Test', slug: 'test' }).draft, true);
});

test('order, newest date, undated slug and file fallback are stable', () => {
  const entry = (id, data) => ({ id, data: { draft: false, ...data } });
  const entries = [entry('z', {}), entry('old', { publicationDate: '2024-01-01' }), entry('new', { publicationDate: '2026-01-01' }), entry('a', {}), entry('last-ordered', { order: 5 }), entry('first', { order: -1 })];
  assert.deepEqual(publicEntries(entries).map(e => e.id), ['first', 'last-ordered', 'new', 'old', 'a', 'z']);
  assert.equal(entries[0].id, 'z', 'does not mutate the caller array');
  assert.deepEqual(publicEntries([entry('b', { order: 1 }), entry('a', { order: 1, publicationDate: '2025-01-01' })]).map(e => e.id), ['a', 'b']);
});

test('duplicate slugs are rejected, including drafts', () => {
  assert.throws(() => publicEntries([{ id: 'a', data: { slug: 'same', draft: true } }, { id: 'b', data: { slug: 'same', draft: false } }]), /Conflicting slug/);
});

test('experiments require exactly one safe destination', () => {
  for (const data of [{}, { slug: 'test', externalUrl: 'https://example.org' }, { externalUrl: 'javascript:alert(1)' }]) {
    assert.equal(experimentSchema.safeParse({ title: 'Test', ...data }).success, false);
  }
  assert.equal(experimentSchema.safeParse({ title: 'Test', slug: 'test' }).success, true);
  assert.equal(experimentSchema.safeParse({ title: 'Test', externalUrl: 'https://example.org' }).success, true);
});

test('schemas reject invalid titles, slugs, dates, draft flags and orders', () => {
  const valid = { title: 'Test', slug: 'test' };
  for (const invalid of [{ title: '' }, { slug: '../test' }, { slug: 'Test' }, { publicationDate: '2025-02-29' }, { publicationDate: 'tomorrow' }, { draft: 'false' }, { order: 1.5 }]) {
    assert.equal(writingSchema.safeParse({ ...valid, ...invalid }).success, false);
  }
  assert.equal(writingSchema.safeParse({ ...valid, publicationDate: '2024-02-29' }).success, true);
});