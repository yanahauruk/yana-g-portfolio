const toggle = document.querySelector('.nav-toggle');
const navLinks = document.querySelector('.nav-links');

if (toggle && navLinks) {
  toggle.addEventListener('click', () => {
    const open = navLinks.classList.toggle('open');
    toggle.setAttribute('aria-expanded', String(open));
  });

  navLinks.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
    });
  });
}

function normalizePath(pathname) {
  if (pathname.endsWith('/index.html')) {
    return pathname.slice(0, -'index.html'.length);
  }
  if (pathname.endsWith('/')) {
    return pathname;
  }
  const lastSlash = pathname.lastIndexOf('/');
  const lastSegment = pathname.slice(lastSlash + 1);
  if (!lastSegment.includes('.')) {
    return `${pathname}/`;
  }
  return pathname;
}

function isHomePath(pathname) {
  return /\/yana-g-portfolio\/$/.test(normalizePath(pathname));
}

document.querySelectorAll('a[href]').forEach((link) => {
  link.addEventListener('click', (event) => {
    const target = new URL(link.href, window.location.href);

    if (target.origin !== window.location.origin) {
      return;
    }

    if (target.hash) {
      return;
    }

    const currentPath = normalizePath(window.location.pathname);
    const targetPath = normalizePath(target.pathname);

    if (currentPath === targetPath || (isHomePath(currentPath) && isHomePath(targetPath))) {
      event.preventDefault();
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  });
});
