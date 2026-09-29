const category = String(args.category || "").trim().toLowerCase();
const link = [...document.querySelectorAll(".side_categories a")].find(a => a.textContent.trim().toLowerCase() === category);
if (!link) throw new Error("unknown category: " + category);
return {url: link.href};
