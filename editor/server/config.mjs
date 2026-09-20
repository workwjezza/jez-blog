import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const editorRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const siteRoot = resolve(editorRoot, '..');
export const dataRoot = join(homedir(), 'Library', 'Application Support', 'Jez Editor');
export const remote = 'https://github.com/workwjezza/jez-blog.git';
export const repository = 'workwjezza/jez-blog';
export const production = 'https://jez.blog';
export const branch = 'main';