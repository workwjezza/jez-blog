import { Editor } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import { Markdown } from '@tiptap/markdown';
import Image from '@tiptap/extension-image';
import { Media, mediaHTML, needsSource } from './media';
import './style.css';
import './gallery.css';

const $ = id => document.getElementById(id);
let token, current, editor, library, timer, saving = Promise.resolve(), dirty = false, generation = 0, frozen = false, publishing = false, pendingMedia, editingMedia = false;
const fields = ['title', 'slug', 'description', 'publicationDate', 'order', 'destination', 'externalUrl'];
function notice(text, error = false) { $('notice').textContent = text; $('notice').classList.toggle('error', error); }
async function api(path, method = 'GET', data, raw = false, extra = {}) {
  const response = await fetch(path, { method, headers: { ...(method === 'GET' ? {} : { 'x-jez-token': token }), ...(raw ? {} : { 'Content-Type': 'application/json' }), ...extra }, body: data === undefined ? undefined : raw ? data : JSON.stringify(data) });
  const result = await response.json(); if (!response.ok) throw new Error(result.error ?? 'Request failed.'); return result;
}
function action(fn) { return async event => { try { await fn(event); } catch (error) { notice(error.message, true); } }; }
function freeze(value) {
  frozen = value;
  $('workspace').querySelectorAll('input,select,textarea,button').forEach(e => { e.disabled = value || e.dataset.unavailable === 'true'; });
  if (!value && current?.source) { $('slug').disabled = true; $('destination').disabled = true; }
  editor?.setEditable(!value);
}
function payload() {
  const data = { ...current };
  if (current.section === 'media') return { ...data, items: structuredClone(current.items), body: '', document: null };
  for (const field of fields) data[field] = $(field).value;
  data.body = current.mode === 'source' ? $('source').value : editor.getMarkdown();
  data.document = current.mode === 'visual' ? editor.getJSON() : null;
  return data;
}
function changed() {
  if (!current || frozen) return;
  dirty = true; generation++; $('save-state').textContent = 'Unsaved changes…';
  clearTimeout(timer); timer = setTimeout(() => save().catch(e => notice(e.message, true)), 650);
}
async function save() {
  clearTimeout(timer);
  saving = saving.catch(() => {}).then(async () => {
    if (!current || !dirty) return;
    const id = current.id, version = generation, data = payload();
    try {
      const result = await api(`/api/entries/${id}`, 'PUT', data);
      if (current.id !== id) return;
      current = { ...result, mode: data.mode, ...(version !== generation && current.section === 'media' ? { items: current.items } : {}) };
      dirty = version !== generation;
      $('save-state').textContent = dirty ? 'Unsaved changes…' : 'Saved on this Mac';
      if (dirty) timer = setTimeout(() => save().catch(e => notice(e.message, true)), 200);
      await refresh(false);
    } catch (error) { $('save-state').textContent = 'Save failed — keep this window open'; throw error; }
  });
  await saving;
  if (dirty) return save();
}
function renderList(id, entries, select) {
  $(id).replaceChildren();
  for (const entry of entries) {
    const button = document.createElement('button'); button.className = 'entry';
    button.textContent = `${entry.title || 'Untitled'} · ${entry.section === 'experiments' ? 'projects' : entry.section}${entry.source ? ' · revision' : ''}`;
    button.onclick = action(() => select(entry)); $(id).append(button);
  }
}
async function refresh(announce = true) {
  library = await api('/api/library');
  renderList('draft-list', [...library.drafts].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt)), e => load(e.id));
  renderList('remote-list', library.library.entries, async e => { if (frozen) return; await save(); const draft = await api('/api/import', 'POST', { path: e.path }); await load(draft.id); });
  $('sync-status').textContent = library.library.updatedAt ? `Last refreshed ${new Date(library.library.updatedAt).toLocaleString()}` : 'Refresh to load existing posts.';
  $('jobs').replaceChildren();
  for (const job of [...library.jobs].reverse()) {
    const box = document.createElement('div'); box.className = 'job';
    const title = document.createElement('strong'); title.textContent = `${job.title} — ${job.state}`;
    const text = document.createElement('p'); text.textContent = job.message;
    box.append(title, text);
    if (job.url) { const a = document.createElement('a'); a.href = job.url; a.textContent = 'Open live post'; a.target = '_blank'; a.rel = 'noopener'; box.append(a); }
    if (job.sha && ['check-required', 'deployment-failed'].includes(job.state)) {
      const button = document.createElement('button'); button.textContent = 'Check deployment'; button.onclick = action(() => api(`/api/jobs/${job.id}/check`, 'POST', {})); box.append(button);
    }
    $('jobs').append(box);
  }
  if (announce) notice('Library loaded. Drafts stay on this Mac.');
}
function updateFields() {
  const gallery = current.section === 'media';
  $('gallery-workspace').hidden = !gallery; $('text-workspace').hidden = gallery;
  const external = current.section === 'projects' && $('destination').value === 'external';
  $('destination-label').hidden = current.section !== 'projects'; $('external-label').hidden = !external;
  $('slug').closest('label').hidden = external;
  $('publish').textContent = current.source ? 'Publish changes' : 'Publish to jez.blog';
}
async function load(id) {
  if (frozen) throw new Error('Wait for the current operation.');
  await save(); current = await api(`/api/entries/${id}`); dirty = false; generation++;
  delete $('slug').dataset.manual;
  if (current.slug) $('slug').dataset.manual = 'true';
  $('welcome').hidden = true; $('workspace').hidden = false;
  for (const field of fields) $(field).value = current[field] ?? '';
  $('source').value = current.body;
  editor?.destroy();
  editor = null;
  if (current.section === 'media') {
    updateFields(); renderGallery(); freeze(false);
    $('save-state').textContent = 'Saved on this Mac';
    notice('Drop files to build your gallery. Nothing goes public until you confirm Publish.');
    return;
  }
  editor = new Editor({
    element: $('editor'), extensions: [StarterKit.configure({ heading: { levels: [2, 3] }, underline: false, link: { openOnClick: false, autolink: false } }), Image, Media, Markdown],
    content: current.document && current.mode === 'visual' ? current.document : current.mode === 'visual' ? current.body : '',
    ...(current.document && current.mode === 'visual' ? {} : { contentType: 'markdown' }),
    editorProps: {
      attributes: { role: 'textbox', 'aria-label': 'Post body', 'aria-multiline': 'true', spellcheck: 'true' },
      handlePaste(view, event) {
        const files = [...(event.clipboardData?.files ?? [])];
        if (files.length) { upload(files).catch(e => notice(e.message, true)); return true; }
        return false;
      },
      handleDrop(view, event) {
        const files = [...(event.dataTransfer?.files ?? [])];
        if (files.length) { upload(files).catch(e => notice(e.message, true)); return true; }
        return false;
      },
      transformPastedHTML(html) {
        const doc = new DOMParser().parseFromString(html, 'text/html');
        doc.querySelectorAll('script,style,iframe,object,embed,img,video,audio').forEach(e => e.remove());
        doc.querySelectorAll('*').forEach(e => [...e.attributes].forEach(a => { if (!['href', 'colspan', 'rowspan'].includes(a.name)) e.removeAttribute(a.name); }));
        return doc.body.innerHTML;
      },
    },
    onUpdate: changed,
  });
  setModeDisplay(); updateFields(); renderMedia(); freeze(false);
  $('save-state').textContent = 'Saved on this Mac';
  notice(current.source ? 'Editing a private revision. The live post remains unchanged until you publish changes.' : 'Local draft. Nothing has been published.');
}
function setModeDisplay() {
  const source = current.mode === 'source'; $('source-label').hidden = !source; $('editor').hidden = source; $('toolbar').hidden = source;
  $('visual-mode').setAttribute('aria-pressed', String(!source)); $('source-mode').setAttribute('aria-pressed', String(source));
}
function renderMedia() {
  $('media-list').replaceChildren();
  for (const asset of current.assets) {
    const button = document.createElement('button'); button.className = 'asset';
    button.textContent = `${asset.name} (${Math.ceil(asset.bytes / 1024)} KB) · Insert`;
    button.onclick = () => chooseMedia(asset); $('media-list').append(button);
  }
}
function chooseMedia(asset) { editingMedia = false; pendingMedia = asset; $('media-name').textContent = asset.name; $('media-alt').value = ''; $('media-caption').value = ''; $('media-dialog').showModal(); }
function renderGallery() {
  $('gallery-items').replaceChildren();
  current.items.forEach((item, index) => {
    const tile = document.createElement('section'); tile.className = 'gallery-tile';
    const media = document.createElement(item.kind === 'image' ? 'img' : item.kind);
    media.src = item.src;
    if (item.kind === 'image') { media.alt = item.alt; media.loading = 'lazy'; }
    else { media.controls = true; media.preload = 'none'; media.setAttribute('aria-label', item.alt || item.caption || item.kind); }
    tile.append(media);
    for (const [field, title] of [['alt', 'Description (optional)'], ['caption', 'Caption (optional)']]) {
      const label = document.createElement('label'), input = document.createElement('input');
      label.textContent = title; input.value = item[field]; input.maxLength = field === 'alt' ? 2000 : 5000;
      input.oninput = () => { current.items[index][field] = input.value; changed(); };
      label.append(input); tile.append(label);
    }
    const controls = document.createElement('div'); controls.className = 'row';
    for (const [label, offset] of [['Move earlier', -1], ['Move later', 1], ['Remove', 0]]) {
      const button = document.createElement('button'); button.textContent = label;
      button.disabled = offset !== 0 && !current.items[index + offset];
      button.dataset.unavailable = String(button.disabled);
      button.onclick = () => {
        if (frozen) return;
        if (!offset) current.items.splice(index, 1);
        else if (current.items[index + offset]) [current.items[index], current.items[index + offset]] = [current.items[index + offset], current.items[index]];
        changed(); renderGallery();
      };
      controls.append(button);
    }
    tile.append(controls); $('gallery-items').append(tile);
  });
}
async function upload(files) {
  if (!current || frozen) throw new Error('Open an editable draft first.');
  await save(); freeze(true);
  try {
    for (const file of files) {
      notice(`Saving ${file.name} privately…`);
      const result = await api(`/api/entries/${current.id}/media`, 'POST', file, true, { 'x-file-name': encodeURIComponent(file.name) });
      current = result.entry; pendingMedia = result.asset;
    }
    if (current.section === 'media') notice(`${files.length} file(s) saved privately. Add optional captions, preview, or publish this batch.`);
    else {
      notice('Media saved privately. Choose Insert to place it in the post.');
      if (files.length === 1) chooseMedia(pendingMedia);
    }
  } finally {
    if (current.section === 'media') renderGallery(); else renderMedia();
    freeze(false); $('upload').value = ''; $('gallery-upload').value = '';
    await refresh(false);
  }
}
function moveMedia(direction) {
  const { state, view } = editor, { selection } = state;
  if (!selection.node || !['jezMedia', 'image'].includes(selection.node.type.name)) return notice('Select a media block first.');
  const from = selection.from, size = selection.node.nodeSize;
  const siblings = []; state.doc.forEach((node, offset) => siblings.push({ node, offset }));
  const index = siblings.findIndex(n => n.offset === from), next = siblings[index + direction];
  if (!next) return;
  const tr = state.tr.delete(from, from + size);
  const position = direction < 0 ? next.offset : next.offset + next.node.nodeSize - size;
  tr.insert(position, selection.node); view.dispatch(tr); editor.commands.focus();
}
document.querySelectorAll('[data-command]').forEach(button => {
  button.onmousedown = e => e.preventDefault();
  button.onclick = action(() => {
    const command = button.dataset.command, chain = editor.chain().focus();
    if (command === 'paragraph') chain.setParagraph().run();
    else if (command === 'h2' || command === 'h3') chain.toggleHeading({ level: Number(command[1]) }).run();
    else if (command === 'link') { const href = prompt('Link destination (https://…, /path, or mailto:). Leave blank to remove.'); if (href === null) return; if (!href) chain.unsetLink().run(); else if (/^(https?:\/\/|mailto:|\/[^/])/.test(href)) chain.extendMarkRange('link').setLink({ href }).run(); else throw new Error('Use an HTTP(S), mailto, or local-path link.'); }
    else if (command === 'up' || command === 'down') moveMedia(command === 'up' ? -1 : 1);
    else if (command === 'edit-media') {
      const node = editor.state.selection.node;
      if (node?.type.name !== 'jezMedia') return notice('Select an inserted media block first.');
      pendingMedia = { url: node.attrs.src, mime: `${node.attrs.kind}/local` }; editingMedia = true;
      $('media-name').textContent = 'Selected media'; $('media-alt').value = node.attrs.alt; $('media-caption').value = node.attrs.caption; $('media-dialog').showModal();
    }
    else if (command === 'remove') { if (['jezMedia', 'image'].includes(editor.state.selection.node?.type.name)) chain.deleteSelection().run(); }
    else ({ bold: () => chain.toggleBold(), italic: () => chain.toggleItalic(), bulletList: () => chain.toggleBulletList(), orderedList: () => chain.toggleOrderedList(), blockquote: () => chain.toggleBlockquote(), codeBlock: () => chain.toggleCodeBlock(), undo: () => chain.undo(), redo: () => chain.redo() }[command])().run();
  });
});
for (const field of fields) $(field).oninput = () => {
  if (field === 'title' && !current.source && !$('slug').dataset.manual) $('slug').value = $('title').value.toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  if (field === 'slug') $('slug').dataset.manual = 'true';
  updateFields(); changed();
};
$('source').oninput = changed;
$('new-writing').onclick = action(async () => { if (frozen) return; await save(); await load((await api('/api/entries', 'POST', { section: 'writing' })).id); });
$('new-project').onclick = action(async () => { if (frozen) return; await save(); await load((await api('/api/entries', 'POST', { section: 'projects' })).id); });
$('new-media').onclick = action(async () => { if (frozen) return; await save(); await load((await api('/api/entries', 'POST', { section: 'media' })).id); });
$('sync').onclick = action(async () => { await save(); freeze(true); notice('Reading GitHub…'); try { await api('/api/sync', 'POST', {}); await refresh(); } finally { freeze(false); } });
$('source-mode').onclick = action(async () => { await save(); if (current.mode === 'source') return; $('source').value = editor.getMarkdown(); current.mode = 'source'; setModeDisplay(); changed(); });
$('visual-mode').onclick = action(async () => {
  await save(); if (current.mode === 'visual') return;
  const source = $('source').value;
  if (needsSource(source)) throw new Error('This Markdown includes HTML or advanced syntax. Keep source mode to preserve it exactly. Preview still works.');
  editor.commands.setContent(source, { contentType: 'markdown', emitUpdate: false });
  if (editor.getMarkdown().trim() !== source.trim() && !confirm('Visual editing normalizes Markdown syntax. Your previous save is recoverable. Switch to visual mode?')) return;
  current.mode = 'visual'; setModeDisplay(); changed();
});
$('recover').onclick = action(async () => { clearTimeout(timer); if (!confirm('Restore the previous local save? Current unsaved edits will be replaced.')) return; dirty = false; await api(`/api/entries/${current.id}/recover`, 'POST', {}); await load(current.id); });
$('upload').onchange = action(e => upload([...e.target.files]));
$('gallery-upload').onchange = action(e => upload([...e.target.files]));
$('gallery-drop').ondragover = event => { event.preventDefault(); };
$('gallery-drop').ondrop = action(async event => { event.preventDefault(); await upload([...event.dataTransfer.files]); });
$('gallery-workspace').onpaste = action(async event => {
  const files = [...(event.clipboardData?.files ?? [])];
  if (files.length) { event.preventDefault(); await upload(files); }
});
$('media-dialog').addEventListener('close', () => {
  if ($('media-dialog').returnValue !== 'insert' || !pendingMedia) return;
  const attrs = { src: pendingMedia.url, kind: pendingMedia.mime.split('/')[0], alt: $('media-alt').value, caption: $('media-caption').value };
  if (current.mode === 'source') { const area = $('source'); area.setRangeText(`\n\n${mediaHTML(attrs)}\n\n`, area.selectionStart, area.selectionEnd, 'end'); changed(); }
  else if (editingMedia) editor.chain().focus().updateAttributes('jezMedia', attrs).run();
  else editor.chain().focus().insertContent({ type: 'jezMedia', attrs }).run();
});
$('preview').onclick = action(async () => {
  await save(); freeze(true); notice('Building a private preview with the blog template…');
  try { const result = await api(`/api/entries/${current.id}/preview`, 'POST', {}); $('preview-frame').src = result.url; $('preview-dialog').showModal(); notice('Private preview ready. Nothing was uploaded.'); }
  finally { freeze(false); }
});
$('close-preview').onclick = () => $('preview-dialog').close();
$('publish').onclick = action(async () => {
  await save(); $('publish-summary').textContent = `${current.title || 'Untitled'} → ${current.section === 'media' ? `Homepage Media gallery (${current.items.length} tiles)` : current.destination === 'external' ? 'Homepage project link' : `https://jez.blog/${current.section}/${current.slug}/`}`;
  $('publish-before').textContent = current.source?.raw ?? '(New entry)';
  $('publish-after').textContent = current.section === 'media' ? JSON.stringify(current.items, null, 2) : JSON.stringify(Object.fromEntries(fields.map(field => [field, current[field]])), null, 2) + '\n\n' + current.body + `\n\nReferenced new attachments: ${current.assets.filter(a => current.body.includes(a.url)).length}`;
  $('publish-confirm').checked = false; $('publish-dialog').showModal();
});
$('publish-dialog').addEventListener('close', action(async () => {
  if ($('publish-dialog').returnValue !== 'publish') return;
  await save(); freeze(true);
  try { await api(`/api/entries/${current.id}/publish`, 'POST', { revision: current.revision, confirmation: 'PUBLISH TO JEZ.BLOG' }); publishing = true; notice('Publication started. Keep the editor running until its status is confirmed.'); await refresh(false); }
  catch (error) { freeze(false); throw error; }
}));
$('stop').onclick = action(async () => { await save(); await api('/api/stop', 'POST', {}); notice('Editor stopped. You can close this tab.'); clearInterval(poll); freeze(true); });
window.addEventListener('beforeunload', event => { if (dirty || frozen) { event.preventDefault(); event.returnValue = ''; } });
const poll = setInterval(async () => {
  try {
    await refresh(false);
    if (publishing && library.jobs.some(j => j.entryId === current?.id) && !library.jobs.some(j => ['building', 'pushing', 'deploying'].includes(j.state))) {
      publishing = false; freeze(false); await load(current.id);
    }
  } catch {}
}, 4000);
try {
  const session = await api('/api/session'); token = session.token;
  $('storage').textContent = `Private storage: ${session.root}. Back up this folder; it is not cloud-synced.`;
  await refresh();
} catch (error) { notice(error.message, true); }