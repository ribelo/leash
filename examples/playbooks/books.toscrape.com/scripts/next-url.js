const link = document.querySelector(".pager .next a");
if (!link) throw new Error("no next category page");
const url = new URL(link.href);
if (url.origin !== location.origin || !url.pathname.startsWith("/catalogue/category/books/")) throw new Error("invalid category pager URL");
return {url: url.href};
