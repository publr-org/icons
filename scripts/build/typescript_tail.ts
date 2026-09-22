export const isIconName = (name: string): name is IconName =>
  Object.prototype.hasOwnProperty.call(ICONS, name);

/** Inline markup: the artwork itself, for a document that has no sprite. */
export const iconSvg = (name: string, className = "size-6"): string =>
  isIconName(name)
    ? `<svg class="${className}" viewBox="${ICON_VIEWBOX}" fill="none" aria-hidden="true">${ICONS[name]}</svg>`
    : "";

const SPRITE_ID = "publr-icon-sprite";
const SVG_NS = "http://www.w3.org/2000/svg";

/**
 * The page's sprite holds one `<symbol id="publr-icon-<name>">` per icon in
 * use. A server writes it into the page with the icons it rendered; this adds
 * what the browser renders on top, creating the hidden sprite the first time.
 */
export function ensureIcon(name: IconName, doc: Document = document): void {
  if (doc.getElementById(`publr-icon-${name}`)) return;
  let sprite = doc.getElementById(SPRITE_ID);
  if (!sprite) {
    sprite = doc.createElementNS(SVG_NS, "svg");
    sprite.id = SPRITE_ID;
    sprite.setAttribute("aria-hidden", "true");
    sprite.setAttribute("style", "display:none");
    doc.body.appendChild(sprite);
  }
  const symbol = doc.createElementNS(SVG_NS, "symbol");
  symbol.id = `publr-icon-${name}`;
  symbol.setAttribute("viewBox", ICON_VIEWBOX);
  symbol.setAttribute("fill", "none");
  symbol.innerHTML = ICONS[name];
  sprite.appendChild(symbol);
}

/** Referenced markup: a pointer into the page's sprite, which gains the icon. */
export const icon = (name: string, className = "size-6", doc: Document = document): string => {
  if (!isIconName(name)) return "";
  ensureIcon(name, doc);
  return `<svg class="${className}" viewBox="${ICON_VIEWBOX}" fill="none" aria-hidden="true"><use href="#publr-icon-${name}"/></svg>`;
};

/** The sprite as markup, for a page assembled outside the browser. */
export const sprite = (names: readonly IconName[] = Object.keys(ICONS) as IconName[]): string =>
  `<svg id="${SPRITE_ID}" style="display:none" aria-hidden="true">${names
    .map((name) => `<symbol id="publr-icon-${name}" viewBox="${ICON_VIEWBOX}" fill="none">${ICONS[name]}</symbol>`)
    .join("")}</svg>`;
