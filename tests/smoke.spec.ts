import { test, expect } from '@playwright/test';

/**
 * Proves the browser launches, renders and runs page scripts without leaving the
 * machine. The generated example specs navigate to playwright.dev, which this
 * environment's network policy blocks, so they fail for reasons unrelated to setup.
 */
test('runs scripts on a page', async ({ page }) => {
  await page.setContent(`
    <h1>Agulha</h1>
    <button id="tick">tick</button>
    <output id="count">0</output>
    <script>
      const out = document.getElementById('count');
      document.getElementById('tick').addEventListener('click', () => {
        out.textContent = String(Number(out.textContent) + 1);
      });
    </script>
  `);

  await expect(page.getByRole('heading')).toHaveText('Agulha');

  await page.getByRole('button', { name: 'tick' }).click();
  await page.getByRole('button', { name: 'tick' }).click();

  await expect(page.locator('#count')).toHaveText('2');
});
