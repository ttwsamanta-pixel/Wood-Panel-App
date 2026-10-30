(() => {
  const input = document.querySelector('#wpam-ad-image');
  const preview = document.querySelector('#wpam-ad-preview');
  if (!input || !preview) return;
  const update = () => { preview.hidden = !input.value.startsWith('https://'); if (!preview.hidden) preview.src = input.value; };
  input.addEventListener('input', update); update();
  document.querySelector('#wpam-ad-upload').addEventListener('click', () => {
    const media = wp.media({title:'Select banner', library:{type:'image'}, multiple:false, button:{text:'Use banner'}});
    media.on('select', () => { input.value = media.state().get('selection').first().toJSON().url; update(); });
    media.open();
  });
})();
