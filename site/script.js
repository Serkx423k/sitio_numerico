// Highlight the active nav link based on current page
(function () {
  const links = document.querySelectorAll("nav ul a");
  const current = window.location.pathname.split("/").pop() || "index.html";

  links.forEach(function (link) {
    const href = link.getAttribute("href").replace("./", "");
    if (href === current) {
      link.style.color = "#fff";
      link.style.fontWeight = "600";
    }
  });
})();
