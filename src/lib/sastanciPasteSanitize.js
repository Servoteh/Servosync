const ALLOWED_TAGS = new Set([
  'p', 'h1', 'h2', 'h3', 'ul', 'ol', 'li', 'b', 'strong', 'i', 'em', 'u', 'a', 'br', 'img',
]);

const STRIP_ATTRS = new Set(['style', 'class', 'id', 'color', 'face', 'font-family', 'font-size', 'background']);

function isSafeHref(href) {
  const h = String(href || '').trim().toLowerCase();
  return h.startsWith('http://') || h.startsWith('https://') || h.startsWith('mailto:');
}

function isSafeImgSrc(src) {
  const s = String(src || '').trim().toLowerCase();
  return s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/');
}

function sanitizeNode(node, { allowInternalBlocks = false } = {}) {
  const children = [...node.childNodes];
  for (const child of children) {
    if (child.nodeType === Node.TEXT_NODE) continue;
    if (child.nodeType !== Node.ELEMENT_NODE) {
      child.remove();
      continue;
    }
    const tag = child.tagName.toLowerCase();
    if (!ALLOWED_TAGS.has(tag)) {
      while (child.firstChild) node.insertBefore(child.firstChild, child);
      child.remove();
      continue;
    }
    const attrs = [...child.attributes];
    for (const attr of attrs) {
      const name = attr.name.toLowerCase();
      if (STRIP_ATTRS.has(name)) {
        child.removeAttribute(attr.name);
        continue;
      }
      if (tag === 'a' && name === 'href') {
        if (!isSafeHref(attr.value)) child.removeAttribute('href');
        continue;
      }
      if (tag === 'img' && name === 'src') {
        if (!isSafeImgSrc(attr.value)) child.removeAttribute('src');
        continue;
      }
      if (name !== 'href' && name !== 'src' && name !== 'alt' && name !== 'title') {
        child.removeAttribute(attr.name);
      }
    }
    if (tag === 'a' && child.hasAttribute('href')) {
      child.setAttribute('target', '_blank');
      child.setAttribute('rel', 'noopener noreferrer');
    }
    if (!allowInternalBlocks && tag === 'img' && child.getAttribute('src')?.startsWith('data:')) {
      /* data URLs from paste are ok */
    }
    sanitizeNode(child, { allowInternalBlocks });
  }
}

/**
 * Sanitizuje HTML iz clipboard-a (Word, Google Docs, Slack).
 * @param {string} html
 */
export function sanitizeZapisnikPasteHtml(html) {
  if (!html || typeof html !== 'string') return '';
  const doc = new DOMParser().parseFromString(html, 'text/html');
  sanitizeNode(doc.body);
  return doc.body.innerHTML;
}
