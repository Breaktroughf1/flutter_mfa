// Accessibility audit of the example app on the web (M2-12, docs/a11y-report.md).
//
// Prints and saves the ARIA tree Flutter exposes for each screen, the Tab
// order, and screenshots, in English (light) and Arabic (dark).
//
// From the repository root:
//   (cd packages/flutter_mfa/example && flutter build web --no-web-resources-cdn)
//   python3 -m http.server 8703 -d packages/flutter_mfa/example/build/web &
//   node tool/web_a11y_audit.js /tmp/a11y-out      # needs Playwright + Chromium
//
// The output directory is created if it does not exist; APP_URL overrides
// the address.
//
// Uses the RFC 6238 test secret; never point it at a real account.
const { chromium } = require('playwright');
const out = process.argv[2] || 'a11y-out';
const fs = require('fs');
fs.mkdirSync(out, { recursive: true });
const log = (...a) => { console.log(...a); fs.appendFileSync(`${out}/audit.txt`, a.join(' ') + '\n'); };
async function enableSemantics(page) {
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  await page.waitForTimeout(500);
}
async function snap(page, name) {
  const aria = await page.locator('flt-semantics-host').ariaSnapshot();
  fs.writeFileSync(`${out}/${name}.aria.yaml`, aria);
  await page.screenshot({ path: `${out}/${name}.png` });
  log(`--- ${name} ---\n${aria}`);
}
async function typeInto(page, name, text) {
  await page.getByRole('textbox', { name }).click();
  await page.keyboard.type(text);
}
async function tabOrder(page, n, name) {
  const seen = [];
  for (let i = 0; i < n; i++) {
    await page.keyboard.press('Tab');
    await page.waitForTimeout(100);
    seen.push(await page.evaluate(() => {
      const e = document.activeElement;
      return e ? `${e.getAttribute('role') || e.tagName.toLowerCase()}:${(e.getAttribute('aria-label') || e.textContent || '').trim().slice(0, 60)}` : 'none';
    }));
  }
  log(`--- tab order (${name}) ---\n` + seen.join('\n'));
}
(async () => {
  const browser = await chromium.launch();
  for (const [locale, scheme] of [['en-US', 'light'], ['ar', 'dark']]) {
    const ctx = await browser.newContext({ viewport: { width: 420, height: 860 }, locale, colorScheme: scheme });
    const page = await ctx.newPage();
    page.on('pageerror', (e) => log('pageerror', e.message));
    await page.goto(process.env.APP_URL || 'http://localhost:8703/');
    await enableSemantics(page);
    await page.getByRole('button', { name: 'Add account' }).waitFor({ timeout: 30000 });
    if (locale === 'en-US') await snap(page, '01-empty');
    await page.getByRole('button', { name: 'Add account' }).click();
    await page.getByText('Enter setup key').click();
    await typeInto(page, 'Issuer (optional)', 'Breaktrough');
    await typeInto(page, 'Account name', 'alice@example.com');
    await typeInto(page, 'Secret key (Base32)', 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await page.waitForTimeout(1500);
    await snap(page, `02-list-${locale}-${scheme}`);
    if (locale === 'en-US') {
      await tabOrder(page, 8, 'list');
      await page.getByRole('button', { name: /Breaktrough/ }).first().click();
      await page.waitForTimeout(1000);
      await snap(page, '03-detail');
      await page.getByRole('button', { name: 'Back' }).click();
      await page.waitForTimeout(500);
      await page.getByRole('button', { name: 'Relying-party demo' }).click();
      await page.getByRole('button', { name: 'Generate secret' }).click();
      await page.waitForTimeout(800);
      await snap(page, '04-relying-party');
      await tabOrder(page, 12, 'relying-party');
    }
    await ctx.close();
  }
  await browser.close();
})().catch((e) => { log('FAILED', e.message.split('\n')[0]); process.exit(1); });
