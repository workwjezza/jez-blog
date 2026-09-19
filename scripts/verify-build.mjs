import assert from 'node:assert/strict';
import { cp, mkdir, mkdtemp, readdir, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../', import.meta.url));
const scratch = await mkdtemp(join(tmpdir(), 'jez-blog-verify-'));
const astro = join(root, 'node_modules/astro/bin/astro.mjs');
async function files(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  return (await Promise.all(entries.map(e => e.isDirectory() ? files(join(directory, e.name)) : join(directory, e.name)))).flat();
}
function build(expectSuccess = true) {
  const result = spawnSync(process.execPath, [astro, 'build'], { cwd: scratch, encoding: 'utf8', env: { ...process.env, ASTRO_TELEMETRY_DISABLED: '1' } });
  if (expectSuccess) assert.equal(result.status, 0, result.stdout + result.stderr);
  else assert.notEqual(result.status, 0, 'Invalid content must fail the build');
  return result.stdout + result.stderr;
}
async function output() {
  return (await Promise.all((await files(join(scratch, 'dist'))).map(f => readFile(f, 'utf8')))).join('\n');
}
async function fixture(section, name, frontmatter, body = 'Verification-only body.') {
  await writeFile(join(scratch, 'src/content', section, `${name}.md`), `---\n${frontmatter}\n---\n\n${body}\n`);
}
function browser(stage) {
  if (process.env.JEZ_BROWSER !== '1') return;
  const result = spawnSync(process.execPath, [join(root, 'scripts/verify-browser.mjs'), scratch, stage], { encoding: 'utf8', env: process.env });
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  assert.equal(result.status, 0, `Browser verification failed at ${stage}`);
}

try {
  for (const name of ['src', 'astro.config.mjs', 'tsconfig.json', 'package.json']) {
    await cp(join(root, name), join(scratch, name), { recursive: true });
  }
  await symlink(join(root, 'node_modules'), join(scratch, 'node_modules'), 'dir');
  // Tests never modify the real content directories, even once the blog is populated.
  for (const section of ['writing', 'experiments']) {
    await rm(join(scratch, 'src/content', section), { recursive: true, force: true });
    await mkdir(join(scratch, 'src/content', section), { recursive: true });
  }
  build();
  let html = await readFile(join(scratch, 'dist/index.html'), 'utf8');
  assert.match(html, /<h1>Jeremy \(Jez\)<\/h1>/);
  assert.match(html, /Experiments:/);
  assert.match(html, /Writing:/);
  assert.equal((html.match(/<hr\b/g) ?? []).length, 1);
  assert.equal((html.match(/<a\b/g) ?? []).length, 4);
  assert.doesNotMatch(html, /<p\b|<ul\b|<script\b|<button\b|<footer\b|<aside\b/);
  const expected = [
    ['Twitter', 'https://x.com/jezzanaut'], ['IG', 'https://instagram.com/jezzabaige'],
    ['YouTube', 'https://youtube.com/jezzanaut'], ['GitHub', 'https://github.com/workwjezza'],
  ];
  let last = -1;
  for (const [label, href] of expected) {
    const position = html.indexOf(`href="${href}">${label}</a>`);
    assert.ok(position > last, `${label} has the correct URL and order`);
    last = position;
  }
  assert.equal((await files(join(scratch, 'dist'))).filter(f => f.endsWith('.html')).length, 1);
  assert.doesNotMatch(await output(), /jacob|zora|coinbase|coming soon|nothing here yet|Attention markets|Tangents/i);
  browser('empty');
  console.log('PASS: genuinely empty build, exact identity/socials, no extra homepage markup or reference metadata.');

  const configPath = join(scratch, 'src/config/site.ts');
  const config = await readFile(configPath, 'utf8');
  await writeFile(configPath, config.replace("bio: ''", "bio: '   '"));
  build();
  assert.doesNotMatch(await readFile(join(scratch, 'dist/index.html'), 'utf8'), /class="bio"|name="description"/);
  await writeFile(configPath, config.replace("bio: ''", "bio: 'Verification bio.'"));
  build();
  html = await readFile(join(scratch, 'dist/index.html'), 'utf8');
  assert.match(html, /<p class="bio">Verification bio\.<\/p>/);
  assert.match(html, /name="description" content="Verification bio\."/);
  await writeFile(configPath, config);
  console.log('PASS: whitespace bio omitted; configured bio renders without a layout edit.');

  const long = 'longword'.repeat(60);
  const markdown = `A paragraph with **strong text**, *emphasis*, and a [link](https://example.org).\n\n## Heading\n\n- One\n- Two\n\n1. First\n2. Second\n\n> A quotation.\n\n\`inline code\`\n\n\`\`\`js\nconst longValue = "${long}";\n\`\`\`\n\nhttps://example.org/${long}\n\n![Verification image](/verify.svg)\n\n| A | B |\n|---|---|\n| ${long} | value |`;
  await mkdir(join(scratch, 'public'));
  await writeFile(join(scratch, 'public/verify.svg'), '<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="200"><rect width="1200" height="200" fill="#ddd"/></svg>');
  await fixture('writing', 'published', `title: "Verification ${long}"\nslug: verification-post\ndraft: false\npublicationDate: "2026-09-19"\norder: 1`, markdown);
  await fixture('writing', 'undated', 'title: Undated verification\nslug: undated\ndraft: false');
  await writeFile(join(scratch, 'src/content/writing/published-image.svg'), '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><title>PUBLIC_LOCAL_IMAGE</title></svg>');
  await fixture('writing', 'undated', 'title: Undated verification\nslug: undated\ndraft: false', '![Published local image](./published-image.svg)');
  await writeFile(join(scratch, 'src/content/writing/secret-image.svg'), '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><title>SECRET_DRAFT_IMAGE</title></svg>');
  await fixture('writing', 'draft', 'title: SECRET_DRAFT_TITLE\nslug: secret-draft\ndraft: true', 'SECRET_DRAFT_BODY\n\n![Private image](./secret-image.svg)');
  await fixture('writing', 'default-draft', 'title: SECRET_DEFAULT_TITLE\nslug: secret-default', 'SECRET_DEFAULT_BODY');
  await fixture('experiments', 'local', 'title: Local verification\nslug: local-verification\ndraft: false\ndescription: A short verification description.', markdown);
  await fixture('experiments', 'external', `title: "External ${long}"\nexternalUrl: https://example.org\ndraft: false\norder: -1\ndescription: "${long}"`);
  await fixture('experiments', 'draft-local', 'title: SECRET_EXPERIMENT\nslug: secret-experiment\ndraft: true', 'SECRET_EXPERIMENT_BODY');
  await fixture('experiments', 'draft-external', 'title: SECRET_EXTERNAL\nexternalUrl: https://example.org/secret-external\ndraft: true');
  build();
  const paths = (await files(join(scratch, 'dist'))).filter(f => f.endsWith('.html')).map(f => f.slice(join(scratch, 'dist').length));
  assert.deepEqual(paths.sort(), ['/experiments/local-verification/index.html', '/index.html', '/writing/undated/index.html', '/writing/verification-post/index.html']);
  assert.doesNotMatch(await output(), /SECRET_|secret-draft|secret-default|secret-experiment|secret-external/);
  assert.match(await output(), /PUBLIC_LOCAL_IMAGE/);
  html = await readFile(join(scratch, 'dist/writing/verification-post/index.html'), 'utf8');
  for (const tag of ['h1', 'h2', 'p', 'ul', 'ol', 'blockquote', 'pre', 'code', 'img', 'table', 'time']) assert.match(html, new RegExp(`<${tag}\\b`));
  assert.match(html, /datetime="2026-09-19"/);
  assert.doesNotMatch(await readFile(join(scratch, 'dist/writing/undated/index.html'), 'utf8'), /<time\b/);
  assert.match(html, /href="\/">← Back/);
  browser('populated');
  console.log('PASS: public routes and Markdown; explicit/default drafts excluded from every built file.');

  await fixture('writing', 'collision', 'title: Conflicting verification\nslug: verification-post\ndraft: true');
  assert.match(build(false), /Conflicting slug/);
  await rm(join(scratch, 'src/content/writing/collision.md'));
  await fixture('experiments', 'invalid', 'title: Invalid verification\nslug: invalid\nexternalUrl: https://example.org');
  assert.match(build(false), /exactly one destination/);
  await rm(join(scratch, 'src/content/experiments/invalid.md'));

  // Unpublishing must remove routes left by a previous build, not just omit new ones.
  await fixture('writing', 'published', 'title: SECRET_UNPUBLISHED\nslug: verification-post\ndraft: true');
  await fixture('writing', 'undated', 'title: SECRET_UNDATED\nslug: undated\ndraft: true');
  await fixture('experiments', 'local', 'title: SECRET_LOCAL\nslug: local-verification\ndraft: true');
  await fixture('experiments', 'external', 'title: SECRET_URL\nexternalUrl: https://example.org\ndraft: true');
  build();
  assert.equal((await files(join(scratch, 'dist'))).filter(f => f.endsWith('.html')).length, 1);
  assert.doesNotMatch(await output(), /SECRET_|Verification-only body|PUBLIC_LOCAL_IMAGE/);
  console.log('PASS: conflicting slugs/invalid destinations fail; unpublishing removes old public routes.');
} finally {
  await rm(scratch, { recursive: true, force: true });
  console.log('Removed isolated fixture project; real content and production output were not touched.');
}