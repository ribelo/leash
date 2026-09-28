// Books on the listing page in the tab: one record per book card. args.max_price (optional, "20" or "£20.00")
// keeps only the books strictly cheaper than that. Runs on the page's own DOM; no model sees the records.
// Side effect, on purpose: the pager is scrolled into view, because the next-page step must find its link in the
// viewport-filtered element table the operator level is shown.
const words = {One: 1, Two: 2, Three: 3, Four: 4, Five: 5};
const limit = args.max_price === undefined || args.max_price === '' ? null : Number(String(args.max_price).replace(/[^0-9.]/g, '') || NaN);
if (limit !== null && !Number.isFinite(limit)) throw new Error('max_price is not a number: ' + args.max_price);
const category = document.querySelector('.page-header h1')?.textContent.trim();
const cards = [...document.querySelectorAll('article.product_pod')];
if (!category || cards.length === 0) throw new Error('not a category listing page: ' + location.href);
const books = cards.map(card => ({
  title: card.querySelector('h3 a').getAttribute('title'),
  price: Number(card.querySelector('.price_color').textContent.replace(/[^0-9.]/g, '')),
  url: card.querySelector('h3 a').href,
  category,
  rating: words[[...card.querySelector('.star-rating').classList].find(c => c in words)],
  availability: card.querySelector('.availability').textContent.trim(),
}));
document.querySelector('.pager')?.scrollIntoView({block: 'center'});
return limit === null ? books : books.filter(book => book.price < limit);
