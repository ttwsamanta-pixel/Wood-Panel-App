const { chromium } = require('../../artifacts/ui-tools/node_modules/playwright');
const { pathToFileURL } = require('node:url');
const path = require('node:path');
(async () => {
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1280,height:900}});
  const errors = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto(pathToFileURL(path.resolve('artifacts/dual-edition/settings-preview.html')).href);
  await page.screenshot({path:'artifacts/dual-edition/settings-desktop.png',fullPage:true});
  await page.getByRole('button',{name:'Categories',exact:true}).click();
  await page.getByRole('searchbox').fill('wood');
  if (await page.locator('[data-field="home_categories"] li:visible').count() !== 1) throw Error('Search failed');
  await page.locator('[data-field="home_categories"] li:visible input').check();
  await page.getByRole('searchbox').fill('');
  if (await page.locator('[data-field="home_categories"] input:checked').count() !== 1) throw Error('Selection lost during search');
  await page.getByRole('button',{name:'Promotional banners',exact:true}).click();
  await page.getByRole('button',{name:'Add banner',exact:true}).click();
  await page.getByRole('button',{name:'Upload / choose image',exact:true}).filter({visible:true}).first().click();
  if (!await page.evaluate(() => window.mediaOpened)) throw Error('Media picker was not opened');
  await page.locator('#wpam-banners input[name$="[label]"]').fill('Test banner');
  await page.getByRole('button',{name:'Add banner',exact:true}).click();
  const rows = page.locator('.wpam-banner');
  await rows.nth(1).locator('input[name$="[label]"]').fill('Second banner');
  await rows.nth(1).getByRole('button',{name:'Move up',exact:true}).click();
  if (await rows.first().locator('input[name$="[label]"]').inputValue() !== 'Second banner') throw Error('Reordering failed');
  if (await rows.first().locator('input[name$="[label]"]').getAttribute('name') !== 'wpam_settings[banners][0][label]') throw Error('Banner names not reindexed');
  for (const [tab, placement] of [['Inline advertisements','inline_ads'],['Footer advertisements','footer_ads']]) {
    await page.getByRole('button',{name:tab,exact:true}).click();
    await page.getByRole('button',{name:'Add banner',exact:true}).click();
    const list = page.locator(`[data-placement="${placement}"].wpam-banner-list`);
    await list.locator('input[name$="[image_url]"]').fill('https://example.com/ad.png');
    if (placement === 'footer_ads') {
      await list.locator('select').selectOption('350x100');
      await page.locator('.wpam-add-banner[data-placement="footer_ads"]').evaluate(button => button.click());
      await list.locator('.wpam-banner').last().getByRole('button',{name:'Move up',exact:true}).evaluate(button => button.click());
      const tall = list.locator('.wpam-banner').last().locator('select');
      if (await tall.inputValue() !== '350x100' || await tall.getAttribute('name') !== 'wpam_settings[footer_ads][1][size]') throw Error('Footer size/order lost: ' + await tall.inputValue() + ' ' + await tall.getAttribute('name'));
      await list.locator('.wpam-banner').first().getByRole('button',{name:'Remove',exact:true}).evaluate(button => button.click());
      if (await tall.count() !== 1) throw Error('Footer size selector missing');
    }
    if (await list.locator('input[name$="[image_url]"]').getAttribute('name') !== `wpam_settings[${placement}][0][image_url]`) throw Error('Ad placement field mismatch');
    await page.screenshot({path:`artifacts/dual-edition/${placement}-settings.png`,fullPage:true});
    await list.getByRole('button',{name:'Remove',exact:true}).evaluate(button => button.click());
    if (await list.locator('.wpam-banner').count() !== 0) throw Error('Removing ad failed');
  }
  await page.getByRole('button',{name:'Promotional banners',exact:true}).click();
  await page.setViewportSize({width:390,height:844});
  await page.screenshot({path:'artifacts/dual-edition/settings-mobile.png',fullPage:true});
  if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw Error('Mobile horizontal overflow');
  if (errors.length) throw Error(errors.join('\n'));
  await browser.close();
  console.log('Settings UI: tabs, search, selection, media trigger, banner ordering and responsive checks passed.');
})().catch(e => {console.error(e); process.exit(1)});
