export const isIconName = (name: string): name is IconName =>
  Object.prototype.hasOwnProperty.call(ICONS, name);

export const iconSvg = (name: string, className = "size-6"): string =>
  isIconName(name)
    ? `<svg class="${className}" viewBox="${ICON_VIEWBOX}" fill="none" aria-hidden="true">${ICONS[name]}</svg>`
    : "";

export const iconRef = (name: string | undefined, prefix = "publr-icon"): string =>
  name && isIconName(name) ? `#${prefix}-${name}` : "";

export function mountIconSprite(
  doc: Document = document,
  prefix = "publr-icon",
): SVGSVGElement {
  const existing = doc.getElementById(`${prefix}-sprite`);
  if (existing?.namespaceURI === "http://www.w3.org/2000/svg")
    return existing as SVGSVGElement;
  const host = doc.createElement("div");
  host.innerHTML = `<svg id="${prefix}-sprite" style="display:none" aria-hidden="true">${Object.entries(ICONS)
    .map(([name, body]) => `<symbol id="${prefix}-${name}" viewBox="${ICON_VIEWBOX}" fill="none">${body}</symbol>`)
    .join("")}</svg>`;
  const sprite = host.firstElementChild as SVGSVGElement;
  doc.body.appendChild(sprite);
  return sprite;
}
