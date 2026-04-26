/**
 * Minimalni whitelist HTML sanitizer — bez DOMPurify.
 *
 * Dozvoljena lista elemenata: b, i, u, strong, em, br, p, ul, ol, li, a.
 * Jedini dozvoljen atribut: href na <a> (samo http/https/mailto).
 * Svi ostali tagovi se strip-uju (sadržaj ostaje), atributi se brišu.
 *
 * Ne pokušavati proširivati listu bez analize XSS vektora.
 */

const ALLOWED_TAGS = new Set(['b', 'i', 'u', 'strong', 'em', 'br', 'p', 'ul', 'ol', 'li', 'a']);

/**
 * Sanitizuj HTML string pre čuvanja ili prikaza.
 * @param {string} html
 * @returns {string}
 */
export function sanitizeHtml(html) {
  if (!html || typeof html !== 'string') return '';
  const doc = new DOMParser().parseFromString(html, 'text/html');
  sanitizeNode(doc.body);
  return doc.body.innerHTML;
}

function sanitizeNode(node) {
  const children = [...node.childNodes];
  for (const child of children) {
    if (child.nodeType === Node.TEXT_NODE) continue;
    if (child.nodeType !== Node.ELEMENT_NODE) {
      child.remove();
      continue;
    }
    const tag = child.tagName.toLowerCase();
    if (!ALLOWED_TAGS.has(tag)) {
      /* Strip tag, preserve children */
      while (child.firstChild) node.insertBefore(child.firstChild, child);
      child.remove();
    } else {
      /* Remove all attributes except safe href on <a> */
      const attrs = [...child.attributes];
      for (const attr of attrs) {
        if (tag === 'a' && attr.name === 'href') {
          const href = attr.value.trim().toLowerCase();
          if (!href.startsWith('http://') && !href.startsWith('https://') && !href.startsWith('mailto:')) {
            child.removeAttribute('href');
          }
        } else {
          child.removeAttribute(attr.name);
        }
      }
      /* Add safe target/rel on links */
      if (tag === 'a' && child.hasAttribute('href')) {
        child.setAttribute('target', '_blank');
        child.setAttribute('rel', 'noopener noreferrer');
      }
      sanitizeNode(child);
    }
  }
}

/**
 * Strip sve HTML tagove, vrati čist tekst.
 * @param {string} html
 * @returns {string}
 */
export function htmlToText(html) {
  if (!html || typeof html !== 'string') return '';
  const doc = new DOMParser().parseFromString(html, 'text/html');
  return doc.body.textContent || '';
}
