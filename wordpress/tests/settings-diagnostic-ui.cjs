const fs = require('fs');
const path = require('path');
const { chromium } = require('../../artifacts/ui-tools/node_modules/playwright');
(async () => {
  const root = path.resolve(__dirname, '../../artifacts/wp-test/wordpress/wp-content/mu-plugins');
  fs.mkdirSync(root, {recursive:true});
  const diagnostic = path.join(root, 'wpam-settings-diagnostic.php');
  const simulation = path.join(root, 'wpam-test-redirect.php');
  if (fs.existsSync(diagnostic) || fs.existsSync(simulation)) throw Error('Fixture files already exist');
  let browser;
  try {
    fs.copyFileSync(path.resolve(__dirname, '../../artifacts/dual-edition/wpam-settings-diagnostic.php'), diagnostic);
    fs.writeFileSync(simulation, `<?php
add_action('admin_init', function () {
 if (($_GET['page'] ?? '') === 'wpam-configuration') {
  wp_safe_redirect(home_url('/404/')); exit;
 }
});`);
    browser = await chromium.launch({headless:true});
    const page = await browser.newPage();
    await page.goto('http://127.0.0.1:8097/wp-login.php');
    await page.locator('#user_login').fill('banneradmin');
    await page.locator('#user_pass').fill('LocalBannerTest-927!');
    await Promise.all([page.waitForURL('**/wp-admin/**'), page.locator('#wp-submit').click()]);
    await page.goto('http://127.0.0.1:8097/wp-admin/options-general.php?page=wpam-configuration');
    if (!page.url().includes('/404/')) throw Error('Simulated redirect did not run');
    await page.goto('http://127.0.0.1:8097/wp-admin/');
    const text = await page.locator('.notice-info').allTextContents();
    if (!text.join('\n').includes('wpam-test-redirect.php')) throw Error('Redirect source was not captured');
    console.log('Diagnostic identifies the redirecting plugin file after returning to Dashboard.');
  } finally {
    if (browser) await browser.close();
    for (const file of [diagnostic, simulation]) if (fs.existsSync(file)) fs.unlinkSync(file);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
