/**
 * Jedinice testovi za processBatch — bez pravog Supabase-a ni MSSQL-a.
 * Pokreće: `npm test` u workers/loc-sync-mssql.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { processBatch } from '../src/processor.js';

function silentLogger() {
  return { debug() {}, info() {}, warn() {}, error() {} };
}

test('processBatch: sve uspešno → ok=N, failed=0', async () => {
  const calls = { synced: [], failed: [], applied: [] };
  const supabase = {
    async markSynced(id) {
      calls.synced.push(id);
      return true;
    },
    async markFailed(id, err) {
      calls.failed.push({ id, err });
      return true;
    },
  };
  const mssql = {
    async applyLocationEvent(evt) {
      calls.applied.push(evt.eventId);
      return { returnValue: 0, output: {} };
    },
  };
  const events = [
    { id: 'e1', source_record_id: 's1', attempts: 0, payload: { a: 1 } },
    { id: 'e2', source_record_id: 's2', attempts: 0, payload: { b: 2 } },
  ];
  const res = await processBatch({ supabase, mssql, logger: silentLogger() }, events);
  assert.equal(res.ok, 2);
  assert.equal(res.failed, 0);
  assert.deepEqual(calls.synced, ['e1', 'e2']);
  assert.deepEqual(calls.applied, ['e1', 'e2']);
  assert.equal(calls.failed.length, 0);
});

test('processBatch: MSSQL greška → markFailed pozvan sa porukom', async () => {
  const calls = { synced: [], failed: [] };
  const supabase = {
    async markSynced(id) {
      calls.synced.push(id);
      return true;
    },
    async markFailed(id, err) {
      calls.failed.push({ id, err });
      return true;
    },
  };
  const mssql = {
    async applyLocationEvent() {
      throw new Error('SP timeout');
    },
  };
  const events = [{ id: 'e1', source_record_id: 's1', attempts: 3, payload: {} }];
  const res = await processBatch({ supabase, mssql, logger: silentLogger() }, events);
  assert.equal(res.ok, 0);
  assert.equal(res.failed, 1);
  assert.equal(calls.synced.length, 0);
  assert.equal(calls.failed[0].id, 'e1');
  assert.match(calls.failed[0].err, /SP timeout/);
});

test('processBatch: markFailed exception ne ruši loop', async () => {
  const supabase = {
    async markSynced() {
      return true;
    },
    async markFailed() {
      throw new Error('db down');
    },
  };
  const mssql = {
    async applyLocationEvent() {
      throw new Error('x');
    },
  };
  const events = [{ id: 'e1', source_record_id: 's1', attempts: 0, payload: {} }];
  const res = await processBatch({ supabase, mssql, logger: silentLogger() }, events);
  assert.equal(res.failed, 1);
});
