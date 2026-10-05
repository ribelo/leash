/** returns: "book" */
const words = {One: 1, Two: 2, Three: 3, Four: 4, Five: 5};
const category = document.querySelector('.page-header h1')?.textContent.trim();
const cards = [...document.querySelectorAll('article.product_pod')];
if (!category || cards.length === 0) throw new Error('not a category listing page: ' + location.href);
return cards.map(card => ({
  title: card.querySelector('h3 a').getAttribute('title'),
  price: Number(card.querySelector('.price_color').textContent.replace(/[^0-9.]/g, '')),
  url: card.querySelector('h3 a').href,
  category,
  rating: words[[...card.querySelector('.star-rating').classList].find(c => c in words)],
  availability: card.querySelector('.availability').textContent.trim(),
}));
