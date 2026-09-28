// The whole category behind the listing page in the tab, in one call: fetches each page of the listing (the site's own
// pages, with the page's cookies), follows the pager and parses the cards. args.max_price as in list-page;
// args.max_pages (default 50) bounds the crawl. Slower to write than list-page but needs no pagination steps.
const words = {One: 1, Two: 2, Three: 3, Four: 4, Five: 5};
const limit = args.max_price === undefined || args.max_price === '' ? null : Number(String(args.max_price).replace(/[^0-9.]/g, '') || NaN);
if (limit !== null && !Number.isFinite(limit)) throw new Error('max_price is not a number: ' + args.max_price);
const maxPages = Math.min(Number(args.max_pages) || 50, 50);
const books = [];
let url = location.href;
for (let page = 0; url && page < maxPages; page++) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(url + ' answered ' + response.status);
  const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
  const category = doc.querySelector('.page-header h1')?.textContent.trim();
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
return limit === null ? books : books.filter(book => book.price < limit);
