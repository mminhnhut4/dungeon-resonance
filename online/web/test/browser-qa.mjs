// Synthetic loopback QA only. Uses an existing browser; never downloads one.
import { chromium } from '@playwright/test';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
const [identityFile, evidenceRoot, browserPath] = process.argv.slice(2);
if (!identityFile || !evidenceRoot || !browserPath) throw new Error('Pass QA identity file, evidence directory and existing browser executable');
const identity = JSON.parse(await readFile(identityFile, 'utf8'));
await mkdir(evidenceRoot, { recursive: true });
const browser = await chromium.launch({ headless: true, executablePath: browserPath });
const page = await browser.newPage({ viewport: { width: 1440, height: 960 } });
const errors = []; page.on('pageerror', error => errors.push(error.message));
let checks = 0;
function check(ok, message) { checks++; if (!ok) throw new Error(message); }
async function login(email) {
  await page.getByLabel('Email', { exact: true }).fill(email);
  await page.getByLabel('Mật khẩu', { exact: true }).fill('Synthetic QA passphrase 3010');
  await page.getByRole('button', { name: 'Đăng nhập →', exact: true }).click();
  await page.getByRole('heading', { name: email, exact: true }).waitFor();
}
try {
  await page.goto('http://127.0.0.1:5086/');
  await login(identity.email);
  await page.getByText('Phiên bản #1', { exact: true }).waitFor();
  check(await page.locator('.stats strong').nth(2).innerText() === '321', 'SPA reads Godot-owned cloud currency');
  await page.screenshot({ path: path.join(evidenceRoot, 'portal_account_a.png'), fullPage: true });
  await page.getByRole('button', { name: 'Đăng xuất', exact: true }).click();
  await page.getByRole('heading', { name: 'Trở lại hành trình', exact: true }).waitFor();
  check(await page.locator('.stats').count() === 0, 'Logout clears prior account data');
  await login(identity.email.replace('godot-a-', 'godot-b-'));
  await page.getByRole('heading', { name: 'Chưa có bản lưu cloud', exact: true }).waitFor();
  check(await page.locator('.stats').count() === 0, 'B cannot see A summary');
  await page.reload();
  await page.getByRole('heading', { name: 'Trở lại hành trình', exact: true }).waitFor();
  check(await page.evaluate(() => localStorage.length === 0 && sessionStorage.length === 0), 'No session token in browser storage');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({ path: path.join(evidenceRoot, 'portal_mobile_login.png'), fullPage: true });
  check(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), 'Mobile has no horizontal overflow');
  check(errors.length === 0, 'No React/runtime page errors: ' + errors.join(';'));
  const result = { status: 'PASS', checks, errors, source: 'actual loopback API with synthetic SQLite QA host; NOT PostgreSQL validation', browser: 'existing Edge headless' };
  await writeFile(path.join(evidenceRoot, 'result.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
} finally { await browser.close(); }
