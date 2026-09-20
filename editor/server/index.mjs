import { readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { createApp } from './http.mjs';
import { dataRoot } from './config.mjs';
import { atomicJson } from './files.mjs';

const lock = join(dataRoot, 'session.json');
const open = url => spawn('open', [url], { stdio: 'ignore' });
if (process.argv.includes('--stop')) {
  const session = JSON.parse(await readFile(lock, 'utf8'));
  const response = await fetch(`${session.origin}/api/stop`, { method: 'POST', headers: { origin: session.origin, 'x-jez-token': session.token } });
  if (!response.ok) throw new Error((await response.json()).error);
  console.log('Jez Editor stopped.');
} else {
  let existing;
  try {
    const session = JSON.parse(await readFile(lock, 'utf8'));
    const response = await fetch(`${session.origin}/api/session`, { signal: AbortSignal.timeout(1000) });
    if (response.ok && (await response.json()).token === session.token) existing = session;
  } catch {}
  if (existing) { console.log(`Jez Editor is already open: ${existing.origin}`); if (process.argv.includes('--open')) open(existing.origin); }
  else {
    const app = await createApp({ root: dataRoot, port: 4319 });
    await atomicJson(lock, { origin: app.origin, token: app.token, pid: process.pid });
    console.log(`Jez Editor: ${app.origin}\nPrivate drafts: ${dataRoot}\nClose this terminal or use Stop editor to stop.`);
    if (process.argv.includes('--open')) open(app.origin);
    app.server.on('close', async () => { await rm(lock, { force: true }); });
    for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => {
      if (app.publisher.busy) console.warn('An operation was interrupted. Check its recorded status on restart.');
      app.server.close(); app.server.closeAllConnections();
    });
  }
}