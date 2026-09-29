// The whole category behind the listing page in the tab, in one call: fetches each page of the listing (the site's own
// pages, with the page's cookies), follows the pager and parses the cards. args.max_price as in list-page;
// args.max_pages (default 50) bounds the crawl. Slower to write than list-page but needs no pagination steps.
const words = {One: 1, Two: 2, Three: 3, Four: 4, Five: 5};
const limit = args.max_price === undefined || args.max_price === '' ? null : Number(String(args.max_price).replace(/[^0-9.]/g, '') || NaN);
if (limit !== null && !Number.isFinite(limit)) throw new Error('max_price is not a number: ' + args.max_price);
const maxPages = Math.min(Number(args.max_pages) || 50, 50);
const books = [];
let url = location.href;
if (args.category) {
  const category = String(args.category).trim().toLowerCase();
  const link = [...document.querySelectorAll('.side_categories a')]
    .find(a => a.textContent.trim().toLowerCase() === category);
  if (!link) throw new Error('unknown category: ' + args.category);
  url = link.href;
}
const visited = new Set();
for (let page = 0; url && page < maxPages; page++) {
  const target = new URL(url);
  if (target.origin !== location.origin || !target.pathname.startsWith('/catalogue/category/books/'))
    throw new Error('not a same-origin category URL');
  if (visited.has(url)) throw new Error('pagination cycle: ' + url);
  visited.add(url);
  const response = await fetch(url);
  if (!response.ok) throw new Error(url + ' answered ' + response.status);
  const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
  const category = doc.querySelector('.page-header h1')?.textContent.trim();
  if (args.category && category?.toLowerCase() !== String(args.category).trim().toLowerCase())
    throw new Error('category response mismatch');
  const cards = [...doc.querySelectorAll('article.product_pod')];
  if (!category || cards.length === 0) throw new Error('not a category listing page: ' + url);
  for (const card of cards) {
    const link = card.querySelector('h3 a');
    books.push({
      title: link.getAttribute('title'),
      price: Number(card.querySelector('.price_color').textContent.replace(/[^0-9.]/g, '')),
      url: new URL(link.getAttribute('href'), url).href,
      category,
      rating: words[[...card.querySelector('.star-rating').classList].find(c => c in words)],
      availability: card.querySelector('.availability').textContent.trim(),
    });
  }
  const next = doc.querySelector('li.next a');
  url = next ? new URL(next.getAttribute('href'), url).href : null;
}
if (url) throw new Error('category exceeds max_pages');
return limit === null ? books : books.filter(book => book.price < limit);
