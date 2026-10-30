(() => {
  const root = document.querySelector('.wpam-settings');
  if (!root) return;
  const form = root.querySelector('form');
  const reindex = list => list.querySelectorAll('.wpam-banner').forEach((row, index) => {
    row.querySelectorAll('input, select').forEach(input => {
      const key = input.name.match(/\[([^\]]+)\]$/)?.[1];
      input.name = `wpam_settings[${list.dataset.placement}][${index}][${key}]`;
    });
  });
  root.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button) return;
    const row = button.closest('li, .wpam-banner');
    const list = row?.closest('.wpam-banner-list');
    if (button.classList.contains('wpam-up') && row?.previousElementSibling) row.parentNode.insertBefore(row, row.previousElementSibling);
    if (button.classList.contains('wpam-down') && row?.nextElementSibling) row.parentNode.insertBefore(row.nextElementSibling, row);
    if (button.classList.contains('wpam-remove')) row?.remove();
    if (list) { reindex(list); form.dispatchEvent(new Event('change', {bubbles: true})); }
    if (button.classList.contains('wpam-add-banner')) {
      const target = root.querySelector(`.wpam-banner-list[data-placement="${button.dataset.placement}"]`);
      if (!target || target.children.length >= 20) return;
      const item = document.createElement('div'); item.className = 'wpam-banner';
      if (target.dataset.placement === 'footer_ads') {
        const label = document.createElement('label'); label.textContent = 'Banner size';
        const select = document.createElement('select'); select.name = 'wpam_settings[footer_ads][0][size]';
        for (const size of ['350x50', '350x100']) {
          const option = document.createElement('option'); option.value = size; option.textContent = size.replace('x', ' x ') + ' px'; select.append(option);
        }
        label.append(select); item.append(label);
      }
      for (const [key, text] of Object.entries({image_url:'Image URL', link_url:'Link URL (optional)', label:'Accessible label'})) {
        const label = document.createElement('label'); label.textContent = text;
        const input = document.createElement('input'); input.className = 'regular-text'; input.type = key === 'label' ? 'text' : 'url';
        input.name = `wpam_settings[${target.dataset.placement}][0][${key}]`; label.append(input); item.append(label);
      }
      for (const [cls, text] of [['wpam-up','Move up'],['wpam-down','Move down'],['wpam-remove','Remove']]) {
        const action = document.createElement('button'); action.type = 'button'; action.className = `button ${cls}`; action.textContent = text; item.append(action);
      }
      target.append(item); reindex(target); form.dispatchEvent(new Event('change', {bubbles: true}));
    }
  });
  root.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button) return;
    let list;
    if (button.classList.contains('wpam-content-add')) {
      list = root.querySelector(`.wpam-content-list[data-kind="${button.dataset.kind}"]`);
      if (list.children.length >= (button.dataset.kind === 'wallpapers' ? 100 : 200)) return;
      const row = list.firstElementChild.cloneNode(true);
      row.querySelectorAll('.wpam-media').forEach(el => el.remove());
      row.querySelectorAll('input, textarea').forEach(el => { el.value = ''; delete el.dataset.mediaReady; });
      list.append(row);
    }
    if (button.classList.contains('wpam-content-remove')) {
      const row = button.closest('.wpam-content-row'); list = row.parentElement;
      if (list.children.length === 1) row.querySelectorAll('input, textarea').forEach(el => {el.value = ''; el.dispatchEvent(new Event('change'));});
      else row.remove();
    }
    if (list) {
      list.querySelectorAll('.wpam-content-row').forEach((row, i) => row.querySelectorAll('input, textarea').forEach(el => {
        const key = el.name.match(/\[([^\]]+)\]$/)[1];
        el.name = `wpam_settings[${list.dataset.kind}][${i}][${key}]`;
      }));
      enhance(); form.dispatchEvent(new Event('change', {bubbles:true}));
    }
  });
  const nav = document.createElement('nav');
  nav.className = 'wpam-tabs';
  nav.setAttribute('aria-label', 'App settings sections');
  form.before(nav);
  const panels = [];
  Array.from(form.querySelectorAll(':scope > h2')).forEach((heading, i) => {
    const panel = document.createElement('section');
    panel.className = 'wpam-panel'; panel.id = `wpam-section-${i}`;
    heading.before(panel);
    panel.append(heading);
    while (panel.nextElementSibling && panel.nextElementSibling.tagName !== 'H2' && !panel.nextElementSibling.classList.contains('submit')) {
      panel.append(panel.nextElementSibling);
    }
    const button = document.createElement('button');
    button.type = 'button'; button.textContent = heading.textContent;
    button.setAttribute('aria-controls', panel.id);
    button.addEventListener('click', () => {
      panels.forEach(({panel: p, button: b}) => {
        p.hidden = p !== panel; b.setAttribute('aria-pressed', String(p === panel));
      });
      sessionStorage.setItem('wpam-tab', panel.id);
    });
    nav.append(button); panels.push({panel, button});
  });
  const selected = panels.find(({panel}) => panel.id === sessionStorage.getItem('wpam-tab')) || panels[0];
  selected?.button.click();
  form.addEventListener('invalid', event => {
    panels.find(({panel}) => panel.contains(event.target))?.button.click();
  }, true);
  const submit = form.querySelector('.submit');
  if (submit) {
    submit.classList.add('wpam-savebar');
    const status = document.createElement('span'); status.setAttribute('role', 'status');
    status.textContent = 'Changes apply to this edition only.'; submit.prepend(status);
    form.addEventListener('change', () => { status.textContent = 'Unsaved changes'; });
  }
  const list = root.querySelector('[data-field="home_categories"]');
  if (list) {
    const tools = document.createElement('div'); tools.className = 'wpam-category-tools';
    const search = document.createElement('input'); search.type = 'search';
    search.placeholder = 'Search categories'; search.setAttribute('aria-label', 'Search categories');
    const count = document.createElement('span'); count.setAttribute('aria-live', 'polite');
    const update = () => { count.textContent = `${list.querySelectorAll('input:checked').length} selected`; };
    search.addEventListener('input', () => {
      const query = search.value.toLocaleLowerCase().trim();
      list.querySelectorAll('li').forEach(row => { row.hidden = !row.querySelector('label').textContent.toLocaleLowerCase().includes(query); });
    });
    list.addEventListener('change', update); update(); tools.append(search, count); list.before(tools);
  }
  function enhanceImage(input) {
    if (input.dataset.mediaReady) return;
    input.dataset.mediaReady = 'true';
    const holder = document.createElement('div'); holder.className = 'wpam-media';
    const preview = document.createElement('img'); preview.alt = 'Selected image preview';
    const update = () => {
      try { const url = new URL(input.value); preview.hidden = url.protocol !== 'https:'; if (!preview.hidden) preview.src = url.href; }
      catch (_) { preview.hidden = true; }
    };
    preview.addEventListener('error', () => { preview.hidden = true; });
    const choose = document.createElement('button'); choose.type = 'button'; choose.className = 'button'; choose.textContent = 'Upload / choose image';
    choose.addEventListener('click', () => {
      const media = wp.media({title: 'Choose app image', library: {type: 'image'}, multiple: false, button: {text: 'Use this image'}});
      media.on('select', () => {
        const item = media.state().get('selection').first().toJSON();
        if (input.id === 'wpam-preloader_url' && item.mime === 'image/svg+xml') { window.alert('Use PNG, JPG or WebP for the loading image.'); return; }
        input.value = item.url; input.dispatchEvent(new Event('change', {bubbles: true}));
      }); media.open();
    });
    const clear = document.createElement('button'); clear.type = 'button'; clear.className = 'button'; clear.textContent = 'Clear';
    clear.addEventListener('click', () => { input.value = ''; input.dispatchEvent(new Event('change', {bubbles: true})); });
    holder.append(preview, choose, clear); input.after(holder);
    input.addEventListener('change', update); input.addEventListener('input', update); update();
  }
  const enhance = () => root.querySelectorAll('#wpam-logo_url, #wpam-preloader_url, input[name$="[image_url]"]').forEach(enhanceImage);
  enhance();
  root.querySelectorAll('.wpam-banner-list').forEach(list => new MutationObserver(enhance).observe(list, {childList: true, subtree: true}));
})();
