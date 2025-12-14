document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".quarto-listing .card").forEach((card) => {

    // Find the author element Quarto generates
    const authorEl = card.querySelector(".listing-author");
    if (!authorEl) return;

    // Normalize text
    const text = authorEl.textContent.replace(/\s+/g, " ").trim();
    if (!text) return;

    // Take first author only
    const firstAuthor = text.split(",")[0].trim();

    // Take ONLY the first name (before first space)
    const firstName = firstAuthor.split(" ")[0];

    // Replace content
    authorEl.textContent = firstName + " ...";
  });
});


