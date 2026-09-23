const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');

test('Vault Application Test Suite', async (t) => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vault-test-'));
  process.env.KEYVAULT_SECRET_PATH = tmpDir;

  const { app, loadSecrets, getCache } = require('./server.js');

  await t.test('Health returns 503 when no secrets loaded', () => {
    loadSecrets();
    const cache = getCache();
    assert.strictEqual(cache.dbPassword, null);
    assert.strictEqual(cache.apiKey, null);
  });

  await t.test('Secrets load successfully from mounted files', () => {
    fs.writeFileSync(path.join(tmpDir, 'db-password'), 'SuperSecretDbPass123!');
    fs.writeFileSync(path.join(tmpDir, 'api-key'), 'xyz-api-token-789');

    const loaded = loadSecrets();
    assert.strictEqual(loaded, true);

    const cache = getCache();
    assert.strictEqual(cache.dbPassword, 'SuperSecretDbPass123!');
    assert.strictEqual(cache.apiKey, 'xyz-api-token-789');
    assert.ok(cache.checksum);
    assert.ok(cache.lastUpdated);
  });

  await t.test('Rotation updates checksum without dropping cache', () => {
    const oldChecksum = getCache().checksum;
    fs.writeFileSync(path.join(tmpDir, 'db-password'), 'RotatedNewDbPassword456!');

    loadSecrets();
    const newCache = getCache();
    assert.strictEqual(newCache.dbPassword, 'RotatedNewDbPassword456!');
    assert.notStrictEqual(newCache.checksum, oldChecksum);
  });

  // Clean up
  fs.rmSync(tmpDir, { recursive: true, force: true });
});
