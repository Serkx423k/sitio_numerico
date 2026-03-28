
(function () {
  const links = document.querySelectorAll('nav ul a');
  const current = window.location.pathname.split('/').pop() || 'index.html';

  links.forEach(function (link) {
    const href = link.getAttribute('href').replace('./', '');
    if (href === current) {
      link.classList.add('active');
    }
  });
})();


document.addEventListener('DOMContentLoaded', function () {
  const pre = document.getElementById('code-content');
  if (!pre) return;   


  function buildDownload() {
    const blob = new Blob([pre.textContent], { type: 'text/plain' });
    const url  = URL.createObjectURL(blob);
    const dlBtn = document.getElementById('btn-download');
    if (dlBtn) dlBtn.href = url;
  }
  buildDownload();


  window.copyCode = function () {
    navigator.clipboard.writeText(pre.textContent).then(function () {
      const btn = document.getElementById('btn-copy');
      if (!btn) return;
      btn.classList.add('copied');
      btn.innerHTML =
        '<svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg> Copiado';
      setTimeout(function () {
        btn.classList.remove('copied');
        btn.innerHTML =
          '<svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg> Copiar';
      }, 2500);
    });
  };
});
