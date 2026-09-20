import { Node, mergeAttributes } from '@tiptap/core';

export const escape = text => String(text ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export function mediaHTML(attrs) {
  const { src, alt = '', caption = '', kind = 'image' } = attrs;
  const tag = kind === 'image' ? `<img src="${escape(src)}" alt="${escape(alt)}">` : `<${kind} src="${escape(src)}" controls preload="metadata" aria-label="${escape(alt)}"></${kind}>`;
  return `<figure data-jez-media="${escape(kind)}">${tag}${caption ? `<figcaption>${escape(caption)}</figcaption>` : ''}</figure>`;
}
export const Media = Node.create({
  name: 'jezMedia', group: 'block', atom: true, draggable: true,
  addAttributes() {
    return {
      src: { default: '' }, alt: { default: '' }, caption: { default: '' }, kind: { default: 'image' },
    };
  },
  parseHTML() {
    return [{ tag: 'figure[data-jez-media]', getAttrs: element => {
      const media = element.querySelector('img,video,audio');
      return { src: media?.getAttribute('src'), alt: media?.getAttribute('alt') ?? media?.getAttribute('aria-label') ?? '', caption: element.querySelector('figcaption')?.textContent ?? '', kind: element.getAttribute('data-jez-media') };
    } }];
  },
  renderHTML({ node }) {
    const a = node.attrs, kind = ['image', 'video', 'audio'].includes(a.kind) ? a.kind : 'image';
    const tag = kind === 'image' ? ['img', { src: a.src, alt: a.alt }] : [kind, { src: a.src, controls: '', preload: 'metadata', 'aria-label': a.alt }];
    return ['figure', mergeAttributes({ 'data-jez-media': kind }), tag, ['figcaption', {}, a.caption || a.alt]];
  },
  renderMarkdown(node) { return mediaHTML(node.attrs); },
});

export function needsSource(markdown) {
  // Prefer fidelity to a lossy visual import. These constructs stay editable as source.
  return /<[^>]+>|^\s*\|.*\||^\s*\[.*\]:|\[\^|^\s*- \[[ x]\]|^\s*:::|\$\$|^# |^#{4,} |^===+\s*$|!\[[^\]]*\]\(/m.test(markdown);
}