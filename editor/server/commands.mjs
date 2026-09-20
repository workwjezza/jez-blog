import { spawn } from 'node:child_process';

export function command(executable, args, { cwd, timeout = 120000, env = {}, onOutput } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, {
      cwd, shell: false, stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, CI: '1', GIT_TERMINAL_PROMPT: '0', GIT_PAGER: 'cat', ASTRO_TELEMETRY_DISABLED: '1', ...env },
    });
    let output = '', stdout = '';
    const timer = setTimeout(() => { child.kill('SIGTERM'); }, timeout);
    const append = data => { output = (output + data).slice(-100000); onOutput?.(String(data)); };
    child.stdout.on('data', data => { stdout += data; append(data); });
    child.stderr.on('data', append);
    child.on('error', error => { clearTimeout(timer); reject(error); });
    child.on('close', code => {
      clearTimeout(timer);
      if (code !== 0) reject(new Error(`${executable} failed (${code ?? 'timed out'}).\n${output.slice(-12000)}`));
      else resolve(stdout.trim());
    });
  });
}