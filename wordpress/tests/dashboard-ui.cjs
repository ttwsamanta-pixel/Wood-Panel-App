const {chromium} = require('../../artifacts/ui-tools/node_modules/playwright');
(async () => {
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:1000}});
  const errors=[]; page.on('pageerror',error=>errors.push(error.message));
  await page.goto('http://127.0.0.1:8097/wp-login.php');
  await page.locator('#user_login').fill('banneradmin');
  await page.locator('#user_pass').fill('LocalBannerTest-927!');
  await Promise.all([page.waitForURL('**/wp-admin/**'),page.locator('#wp-submit').click()]);
  await page.goto('http://127.0.0.1:8097/wp-admin/admin.php?page=wood-panel-app-settings');
  await page.locator('.wpam-dashboard-sidebar').waitFor();
  await page.getByRole('button',{name:'Contact details',exact:true}).click();
  await page.locator('#contact-usa_address').fill('Local test office\nSecond floor');
  await page.getByRole('button',{name:'Save app settings',exact:true}).click();
  await page.waitForLoadState('domcontentloaded');
  await page.getByRole('button',{name:'Contact details',exact:true}).click();
  if(await page.locator('#contact-usa_address').inputValue()!=='Local test office\nSecond floor') throw Error('Contact save failed');
  await page.screenshot({path:'artifacts/dual-edition/dashboard-contact.png',fullPage:true});
  if(await page.locator('#toplevel_page_wood-panel-app-settings .wp-submenu').isVisible()) throw Error('WordPress submenu still visible');
  for(const [label,heading] of [['Notifications','App Notifications'],['Submissions','App Submissions'],['All banners','App Banners'],['Banner reports','App Banner Reports'],['Add banner','Add New Banner']]) {
    await page.locator('.wpam-dashboard-sidebar').getByRole('link',{name:label,exact:true}).click();
    await page.locator('.wpam-dashboard-sidebar').waitFor();
    if(await page.locator('body').innerText().then(t=>t.includes('critical error'))) throw Error(label+' fatal error');
  }
  for (const label of ['Newsletter','Contact','Profile']) {
    await page.locator('.wpam-submission-links').getByRole('link',{name:label,exact:true}).click();
    await page.locator('.wpam-submission-links a[aria-current]').waitFor();
    if(await page.locator('.wpam-submission-links a[aria-current]').innerText()!==label) throw Error('Wrong active submission');
    if(await page.locator('.wpam-submission-tabs').isVisible()) throw Error('Duplicate tabs visible');
    await page.getByRole('button',{name:'Download CSV',exact:true}).waitFor();
  }
  await page.screenshot({path:'artifacts/dual-edition/dashboard-submissions.png',fullPage:true});
  await page.goto('http://127.0.0.1:8097/wp-admin/admin.php?page=wood-panel-app-settings');
  await page.setViewportSize({width:390,height:844});
  await page.getByRole('button',{name:'Contact details',exact:true}).click();
  if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)) throw Error('Mobile overflow');
  await page.screenshot({path:'artifacts/dual-edition/dashboard-mobile.png',fullPage:true});
  if(errors.length) throw Error(errors.join('\n'));
  await browser.close(); console.log('Dashboard navigation, contact save, hidden WP submenu and mobile layout passed.');
})().catch(error=>{console.error(error);process.exit(1)});
