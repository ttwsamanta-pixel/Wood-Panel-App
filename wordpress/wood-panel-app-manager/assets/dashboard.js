(() => {
  const start = () => {
    const content = document.querySelector('#wpbody-content > .wrap');
    if (!content || !window.wpamDashboard) return;
    document.body.classList.add('wpam-dashboard-page');
    const shell = document.createElement('div'); shell.className = 'wpam-dashboard';
    const side = document.createElement('aside'); side.className = 'wpam-dashboard-sidebar';
    const brand = document.createElement('div'); brand.className = 'wpam-dashboard-brand';
    const name = document.createElement('strong'); name.textContent = 'WOOD & PANEL';
    const edition = document.createElement('span'); edition.textContent = `${wpamDashboard.edition} · App Manager`;
    brand.append(name, edition); side.append(brand);
    const nav = document.createElement('nav'); nav.setAttribute('aria-label', 'App management');
    wpamDashboard.links.forEach(item => {
      const link = document.createElement('a'); link.href = item.url; link.textContent = item.label;
      const target = new URL(item.url); const current = new URL(location.href);
      if (target.pathname === current.pathname && target.search === current.search) link.setAttribute('aria-current', 'page');
      nav.append(link);
      if (item.children) {
        const group = document.createElement('div');
        group.className = 'wpam-submission-links';
        group.setAttribute('aria-label', 'Submission types');
        const page = current.searchParams.get('page');
        const isSubmission = page === 'wpam-submissions' || page === 'wpam-profiles';
        const kind = page === 'wpam-profiles' ? 'profile' : (current.searchParams.get('kind') || 'newsletter');
        if (isSubmission) link.classList.add('wpam-group-active');
        link.removeAttribute('aria-current');
        item.children.forEach(child => {
          const entry = document.createElement('a');
          entry.href = child.url; entry.textContent = child.label;
          if (isSubmission && child.kind === kind) entry.setAttribute('aria-current', 'page');
          group.append(entry);
        });
        nav.append(group);
      }
      if (item.label === 'Application settings') {
        const tabs = content.querySelector('.wpam-tabs');
        if (tabs) nav.append(tabs);
        else {
          const sections = document.createElement('div'); sections.className = 'wpam-section-links';
          wpamDashboard.sections.forEach((label, index) => {
            const section = document.createElement('a'); section.textContent = label;
            section.href = `${item.url}#wpam-section-${index}`; sections.append(section);
          });
          nav.append(sections);
        }
      }
    });
    side.append(nav);
    content.before(shell); shell.append(side, content);
  };
  // Settings creates its panels before the shared shell places the section nav.
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
