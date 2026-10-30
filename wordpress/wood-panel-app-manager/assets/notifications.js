(() => {
  const form = document.getElementById('wpam-notification-form');
  if (!form) return;
  const search = document.getElementById('wpam-news-search');
  const results = document.getElementById('wpam-news-results');
  const selected = document.getElementById('wpam-news-selected');
  const id = document.getElementById('wpam-article-id');
  let timer, controller, version = 0;
  search.addEventListener('input', () => {
    clearTimeout(timer);
    controller?.abort();
    const current = ++version;
    results.replaceChildren();
    if (search.value.trim().length < 2) return;
    timer = setTimeout(async () => {
      controller = new AbortController();
      results.textContent = 'Searching…';
      try {
        const url = new URL(wpamNotifications.url);
        url.search = new URLSearchParams({ action: 'wpam_news_search', _ajax_nonce: wpamNotifications.nonce, q: search.value });
        const response = await fetch(url, { signal: controller.signal, credentials: 'same-origin' });
        const data = await response.json();
        if (current !== version) return;
        if (!response.ok || !data.success) throw new Error('search');
        results.replaceChildren();
        if (!data.data.length) results.textContent = 'No published news found.';
        data.data.forEach(article => {
          const button = document.createElement('button');
          button.type = 'button';
          button.className = 'button';
          button.style.cssText = 'display:block;width:100%;white-space:normal;text-align:left;margin:5px 0;padding:10px;';
          button.textContent = `${article.title} — Published ${article.published} — ID ${article.id}`;
          button.addEventListener('click', () => {
            id.value = article.id;
            selected.textContent = `Selected: ${article.title} — Published ${article.published}${article.image ? ' — Featured image included' : ' — Text notification'}`;
            results.replaceChildren();
          });
          results.append(button);
        });
      } catch (error) {
        if (error.name !== 'AbortError' && current === version) results.textContent = 'Search unavailable. Try again or enter the article ID.';
      }
    }, 300);
  });
  id.addEventListener('input', () => { selected.textContent = ''; });
  form.querySelectorAll('[name="delivery"]').forEach(radio => radio.addEventListener('change', () => {
    const later = form.elements.delivery.value === 'schedule';
    document.getElementById('wpam-schedule').hidden = !later;
    form.elements.send_at.required = later;
    document.getElementById('wpam-notification-submit').value = later ? 'Schedule notification' : 'Send notification';
  }));
  form.addEventListener('submit', () => { document.getElementById('wpam-notification-submit').disabled = true; });
})();
