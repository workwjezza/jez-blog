import { mkdir, mkdtemp, cp, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { randomUUID } from 'node:crypto';
import { command } from './commands.mjs';
import { atomicJson, json, walk, hash, fail, validId } from './files.mjs';
import { parseContent, metadata, publicRoute } from './content.mjs';
import * as config from './config.mjs';

export class Publisher {
  constructor(store, options = {}) {
    this.store = store;
    this.options = { remote: config.remote, branch: config.branch, siteRoot: config.siteRoot, run: command, ...options };
    this.busy = false;
  }
  run(exe, args, opts = {}) { return this.options.run(exe, args, opts); }
  async checkout() {
    await mkdir(join(this.store.root, 'work'), { recursive: true, mode: 0o700 });
    const directory = await mkdtemp(join(this.store.root, 'work', 'checkout-'));
    try {
      await this.run('git', ['clone', '--quiet', '--single-branch', '--branch', this.options.branch, '--', this.options.remote, directory]);
      return directory;
    } catch (error) { await rm(directory, { recursive: true, force: true }); throw error; }
  }
  async sync() {
    if (this.busy) fail('Wait for the current preview or publication to finish.', 409);
    this.busy = true;
    let directory;
    try {
      directory = await this.checkout();
      const entries = [];
      for (const section of ['writing', 'projects', 'experiments', 'media']) {
        for (const file of await walk(join(directory, 'src/content', section))) {
          if (!file.endsWith('.md')) continue;
          const raw = await readFile(file, 'utf8'), { data } = parseContent(raw);
          entries.push({ path: relative(directory, file), section: section === 'experiments' ? 'projects' : section, title: data.title, slug: data.slug, draft: data.draft !== false });
        }
      }
      const cache = join(this.store.root, 'library');
      await rm(cache, { recursive: true, force: true });
      await mkdir(cache, { recursive: true });
      for (const part of ['src/content', 'public']) {
        await cp(join(directory, part), join(cache, part), { recursive: true }).catch(e => { if (e.code !== 'ENOENT') throw e; });
      }
      await atomicJson(join(this.store.root, 'library.json'), { entries, updatedAt: new Date().toISOString() });
      return entries;
    } finally { this.busy = false; if (directory) await rm(directory, { recursive: true, force: true }); }
  }
  async assertUnchanged(entry, checkout) {
    const file = entry.source?.path ?? `src/content/${entry.section}/${entry.slug || entry.id}.md`;
    const current = await readFile(join(checkout, file), 'utf8').catch(e => { if (e.code === 'ENOENT') return null; throw e; });
    if (entry.source && (current === null || hash(current) !== entry.source.hash)) fail('The remote post changed since this revision was opened. Your draft is safe. Resolve the difference with your coding agent before publishing.', 409);
    if (!entry.source && current !== null) fail('That filename already exists on GitHub. Choose another slug.', 409);
    const sections = ['projects', 'experiments'].includes(entry.section) ? ['projects', 'experiments'] : [entry.section];
    for (const candidate of (await Promise.all(sections.map(section => walk(join(checkout, 'src/content', section))))).flat()) {
      if (!candidate.endsWith('.md') || relative(checkout, candidate) === file) continue;
      const { data } = parseContent(await readFile(candidate, 'utf8'));
      if (entry.slug && data.slug === entry.slug) fail('That slug already belongs to another entry, including a draft.', 409);
    }
  }
  async preview(entry) {
    if (this.busy) fail('Another preview or publication is running.', 409);
    metadata(entry, true);
    this.busy = true;
    const id = randomUUID(), directory = join(this.store.root, 'previews', id);
    try {
      await mkdir(directory, { recursive: true });
      for (const part of ['src', 'astro.config.mjs', 'tsconfig.json', 'package.json']) {
        await cp(join(this.options.siteRoot, part), join(directory, part), { recursive: true });
      }
      // Never include unrelated local content or drafts in an entry preview.
      await rm(join(directory, 'src/content'), { recursive: true, force: true });
      await mkdir(join(directory, 'src/content/writing'), { recursive: true });
      await mkdir(join(directory, 'src/content/experiments'), { recursive: true });
      await mkdir(join(directory, 'src/content/projects'), { recursive: true });
      await mkdir(join(directory, 'src/content/media'), { recursive: true });
      const library = join(this.store.root, 'library');
      if (entry.source) {
        // Preserve relative author-supplied assets, but not other Markdown entries.
        for (const file of await walk(join(library, 'src/content'))) {
          if (file.endsWith('.md')) continue;
          const destination = join(directory, relative(library, file));
          await mkdir(join(destination, '..'), { recursive: true });
          await cp(file, destination);
        }
        await cp(join(library, 'public'), join(directory, 'public'), { recursive: true }).catch(e => { if (e.code !== 'ENOENT') throw e; });
      }
      await symlink(join(this.options.siteRoot, 'node_modules'), join(directory, 'node_modules'), 'dir');
      await this.store.materialize(entry, directory, true);
      // Prefix generated assets and homepage links so this private preview stays isolated.
      await writeFile(join(directory, 'preview.config.mjs'), `import config from './astro.config.mjs'; export default {...config, base: '/preview/${id}/'};`);
      await this.run(process.execPath, [join(this.options.siteRoot, 'node_modules/astro/bin/astro.mjs'), 'build', '--config', './preview.config.mjs'], { cwd: directory });
      for (const file of await walk(join(directory, 'dist'))) {
        if (!file.endsWith('.html')) continue;
        const html = await readFile(file, 'utf8');
        await writeFile(file, html.replace(/\b(href|src)="\/(?!\/|preview\/)([^"]*)"/g, `$1="/preview/${id}/$2"`));
      }
      const route = publicRoute(entry);
      return { url: `/preview/${id}/${route}`, id };
    } finally { this.busy = false; }
  }
  async start(entry, confirmation) {
    if (this.busy) fail('A preview or publication is already running.', 409);
    if (confirmation !== 'PUBLISH TO JEZ.BLOG') fail('Publication requires explicit confirmation.');
    metadata(entry, true);
    const jobs = await this.jobs();
    if (jobs.some(j => !['live', 'failed', 'no-changes'].includes(j.state))) fail('Check the previous publication before starting another. Its push may already have succeeded.', 409);
    const job = { id: randomUUID(), entryId: entry.id, revision: entry.revision, title: entry.title, state: 'building', message: 'Preparing an isolated checkout.', createdAt: new Date().toISOString(), sha: null, pushed: false };
    await this.record(job);
    this.busy = true;
    this.execute(entry, job).catch(() => {}).finally(() => { this.busy = false; });
    return job;
  }
  async record(job) { await atomicJson(join(this.store.root, 'jobs', `${job.id}.json`), job); }
  async jobs() { return Promise.all((await walk(join(this.store.root, 'jobs'))).filter(p => p.endsWith('.json')).map(p => json(p))); }
  async execute(entry, job) {
    let directory;
    try {
      directory = await this.checkout();
      if (['media', 'projects', 'experiments'].includes(entry.section)) {
        const features = await json(join(directory, 'src/config/content-features.json'), {});
        const feature = entry.section === 'media' ? 'media' : 'projects';
        if (features[feature] !== 1) fail(`The GitHub site does not support ${feature} yet. Deploy the site update before publishing this entry. Your draft is safe.`);
      }
      await this.assertUnchanged(entry, directory);
      const { file, changed } = await this.store.materialize(entry, directory, true);
      job.message = 'Validating and building the selected entry.'; await this.record(job);
      if (this.options.build) await this.options.build(directory);
      else {
        await this.run('npm', ['ci', '--no-audit', '--no-fund'], { cwd: directory, timeout: 240000 });
        await this.run('npm', ['run', 'build'], { cwd: directory, timeout: 240000 });
      }
      await this.run('git', ['add', '--', ...changed], { cwd: directory });
      const staged = await this.run('git', ['diff', '--cached', '--name-only'], { cwd: directory });
      if (!staged) { job.state = 'no-changes'; job.message = 'The selected entry already matches GitHub.'; await this.record(job); return; }
      if (staged.split('\n').some(path => !changed.includes(path))) fail('Unexpected staged file. Publication stopped.');
      // Do not configure identity globally or alter the working repository.
      const name = await this.run('git', ['config', 'user.name'], { cwd: this.options.siteRoot });
      const email = await this.run('git', ['config', 'user.email'], { cwd: this.options.siteRoot });
      await this.run('git', ['-c', `user.name=${name}`, '-c', `user.email=${email}`, 'commit', '-m', `${entry.source ? 'Update' : 'Publish'} ${entry.section}: ${entry.title}`], { cwd: directory });
      job.sha = await this.run('git', ['rev-parse', 'HEAD'], { cwd: directory });
      job.file = file;
      job.raw = await readFile(join(directory, file), 'utf8');
      job.state = 'pushing'; job.message = 'Pushing only the selected entry and referenced media.'; await this.record(job);
      // A concurrent upstream change causes a safe non-fast-forward rejection. Never force.
      await this.run('git', ['push', 'origin', `HEAD:refs/heads/${this.options.branch}`], { cwd: directory });
      job.pushed = true; job.state = 'deploying'; job.message = 'GitHub accepted the commit. Waiting for Vercel.';
      await this.recordPublished(job);
      await this.record(job);
      await this.monitor(job);
    } catch (error) {
      // A transport failure after push begins is ambiguous: never claim it was not published.
      job.state = job.state === 'pushing' ? 'check-required' : job.pushed ? 'deployment-failed' : 'failed';
      job.message = error.message;
      await this.record(job);
    } finally { if (directory) await rm(directory, { recursive: true, force: true }); }
  }
  async recordPublished(job) {
    const latest = await this.store.get(job.entryId);
    if (job.raw && latest.source?.hash !== hash(job.raw)) {
      latest.source = { path: job.file, hash: hash(job.raw), raw: job.raw };
      latest.publicationDate ||= parseContent(job.raw).data.publicationDate;
      latest.revision++; latest.lastPublishedRevision = job.revision;
      await atomicJson(this.store.path(job.entryId), latest);
    }
  }
  async monitor(job) {
    if (this.options.monitor) { Object.assign(job, await this.options.monitor(job)); await this.record(job); return; }
    for (let attempt = 0; attempt < 60; attempt++) {
      const result = JSON.parse(await this.run('gh', ['api', `repos/${config.repository}/commits/${job.sha}/status`]));
      const vercel = result.statuses.find(s => s.context === 'Vercel');
      if (vercel?.state === 'failure' || vercel?.state === 'error') throw new Error(`Vercel deployment failed. The commit is on GitHub. ${vercel.target_url ?? ''}`);
      if (vercel?.state === 'success') {
        const summary = JSON.parse(await this.run('vercel', ['inspect', config.production, '--json', '--scope', 'jez4', '--non-interactive']));
        const deployment = JSON.parse(await this.run('vercel', ['api', `/v13/deployments/${summary.id}`, '--scope', 'jez4', '--non-interactive', '--raw']));
        if (deployment.readyState === 'READY' && deployment.meta?.githubCommitSha === job.sha) {
          const entry = await this.store.get(job.entryId);
          const url = `${config.production}/${publicRoute(entry)}`;
          const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
          if (response.ok) { job.pushed = true; await this.recordPublished(job); job.state = 'live'; job.message = 'Live on jez.blog.'; job.url = url; await this.record(job); return; }
        }
      }
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
    job.state = 'check-required'; job.message = 'The commit was pushed, but live deployment was not confirmed within five minutes. Use Check deployment; do not publish again.';
    await this.record(job);
  }
  async recheck(id) {
    const job = await json(join(this.store.root, 'jobs', `${validId(id)}.json`));
    if (!job.sha) fail('No commit exists to check. Your draft is safe.');
    if (this.busy) fail('Wait for the running operation.', 409);
    this.busy = true;
    this.reconcile(job).catch(async error => { job.state = 'check-required'; job.message = error.message; await this.record(job); }).finally(() => { this.busy = false; });
    return job;
  }
  async reconcile(job) {
    const checkout = await this.checkout();
    try {
      const ancestors = await this.run('git', ['rev-list', 'HEAD'], { cwd: checkout });
      if (!ancestors.split('\n').includes(job.sha)) {
        job.state = 'failed'; job.message = 'This commit is not on the remote main branch. No publication from it is active. Your draft is safe to review and retry.';
        await this.record(job); return;
      }
      job.pushed = true; await this.recordPublished(job);
      await this.monitor(job);
    } finally { await rm(checkout, { recursive: true, force: true }); }
  }
}