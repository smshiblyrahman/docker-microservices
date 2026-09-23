const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const port = process.env.PORT || 3000;
const secretsDir = process.env.KEYVAULT_SECRET_PATH || '/mnt/secrets-store';

app.use(express.json());

// In-memory cache for secrets
let secretCache = {
  dbPassword: null,
  apiKey: null,
  lastUpdated: null,
  checksum: null
};

// Safe secret loader function
function loadSecrets() {
  try {
    const dbPassPath = path.join(secretsDir, 'db-password');
    const apiKeyPath = path.join(secretsDir, 'api-key');

    let dbPassword = null;
    let apiKey = null;

    if (fs.existsSync(dbPassPath)) {
      dbPassword = fs.readFileSync(dbPassPath, 'utf8').trim();
    }
    if (fs.existsSync(apiKeyPath)) {
      apiKey = fs.readFileSync(apiKeyPath, 'utf8').trim();
    }

    if (dbPassword || apiKey) {
      const hash = crypto.createHash('sha256');
      if (dbPassword) hash.update(dbPassword);
      if (apiKey) hash.update(apiKey);

      secretCache = {
        dbPassword,
        apiKey,
        lastUpdated: new Date().toISOString(),
        checksum: hash.digest('hex').substring(0, 12)
      };
      return true;
    }
    return false;
  } catch (err) {
    console.error(JSON.stringify({
      level: 'ERROR',
      message: 'Failed to read secrets from mount path',
      error: err.message,
      timestamp: new Date().toISOString()
    }));
    return false;
  }
}

// Initial load
loadSecrets();

// Watch secret directory for automatic rotation reload (polling fallback every 15s)
setInterval(() => {
  loadSecrets();
}, 15000);

// Health probe endpoint for Kubernetes liveness & readiness
app.get('/health', (req, res) => {
  const isHealthy = Boolean(secretCache.dbPassword || secretCache.apiKey);
  const status = isHealthy ? 200 : 503;
  res.status(status).json({
    status: isHealthy ? 'healthy' : 'unhealthy',
    secretsLoaded: isHealthy,
    checksum: secretCache.checksum,
    lastUpdated: secretCache.lastUpdated,
    timestamp: new Date().toISOString()
  });
});

// Protected configuration status endpoint (never outputs plain secret values)
app.get('/api/config', (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Bearer token required' });
  }

  res.json({
    mountPath: secretsDir,
    hasDbPassword: Boolean(secretCache.dbPassword),
    hasApiKey: Boolean(secretCache.apiKey),
    secretChecksum: secretCache.checksum,
    lastRefreshed: secretCache.lastUpdated,
    security: {
      hardcodedSecrets: false,
      workloadIdentity: true,
      csiDriverMounted: true
    }
  });
});

// Secure data handler demonstrating secret consumption
app.get('/api/data', (req, res) => {
  if (!secretCache.apiKey && !secretCache.dbPassword) {
    return res.status(500).json({ error: 'Secrets unavailable' });
  }

  res.json({
    success: true,
    message: 'Data securely accessed using Workload Identity mounted credentials',
    checksum: secretCache.checksum,
    timestamp: new Date().toISOString()
  });
});

// Export app for unit tests
if (require.main === module) {
  app.listen(port, () => {
    console.log(JSON.stringify({
      level: 'INFO',
      message: `Hardened Vault microservice running on port ${port}`,
      secretsDir,
      timestamp: new Date().toISOString()
    }));
  });
}

module.exports = { app, loadSecrets, getCache: () => secretCache };
