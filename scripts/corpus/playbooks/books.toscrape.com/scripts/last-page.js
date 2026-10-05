/** returns: "pager" */
if (!location.pathname.startsWith("/catalogue/category/books/") || !document.querySelector("article.product_pod")) throw new Error("not a category listing");
return {done: document.querySelector(".pager .next a") === null};
