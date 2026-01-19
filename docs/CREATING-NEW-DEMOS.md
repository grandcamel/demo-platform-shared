# Creating New Demo Platforms

This guide walks through creating a new demo platform (e.g., "github-demo") using the shared library infrastructure.

## Prerequisites

- Node.js 18+
- Docker and Docker Compose
- Access to the `demo-platform-shared` repository

## Quick Start

1. **Copy an existing demo as a template**
   ```bash
   cp -r confluence-demo github-demo
   cd github-demo
   ```

2. **Update project identifiers**
   - Rename references from `confluence-demo` to `github-demo`
   - Update `queue-manager/package.json` name field
   - Update service names in `docker-compose.yml`

3. **Configure the shared library dependency**
   ```bash
   # In queue-manager/package.json, ensure the path is correct:
   "@demo-platform/queue-manager-core": "file:../../demo-platform-shared/packages/queue-manager-core"
   ```

4. **Install dependencies**
   ```bash
   cd queue-manager && npm install
   ```

5. **Customize API-specific configuration**

## Project Structure

Use this standard structure for consistency:

```
github-demo/
├── docker-compose.yml          # Production orchestration
├── docker-compose.dev.yml      # Development overrides
├── Makefile                    # Build/run commands
├── CLAUDE.md                   # Project documentation
├── queue-manager/              # Node.js WebSocket server
│   ├── server.js               # Express app setup (~150 lines)
│   ├── instrumentation.js      # OTel bootstrap
│   ├── package.json
│   ├── config/
│   │   ├── index.js            # All configuration constants
│   │   └── metrics.js          # OTel metrics (uses shared lib)
│   ├── services/
│   │   ├── state.js            # Shared state management
│   │   ├── session.js          # Session lifecycle (uses shared lib)
│   │   ├── queue.js            # Queue operations
│   │   └── invite.js           # Invite validation (uses shared lib)
│   ├── handlers/
│   │   └── websocket.js        # WebSocket handlers (uses shared lib)
│   ├── routes/
│   │   ├── health.js           # Health endpoints
│   │   ├── session.js          # Session validation
│   │   └── scenarios.js        # Scenario rendering
│   ├── templates/
│   │   └── scenario.html       # HTML template
│   └── static/
│       └── scenario.css        # Styles
├── demo-container/             # Claude + plugin container
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── scenarios/              # Demo scenarios
├── landing-page/               # Static HTML frontend
│   ├── index.html
│   └── styles.css
├── nginx/                      # Reverse proxy configuration
│   ├── nginx.conf
│   └── locations.include
├── observability/              # LGTM stack configuration
│   └── dashboards/
├── scripts/                    # Python maintenance scripts
└── secrets/                    # Credentials (.gitignored)
    └── .env
```

## Using the Shared Library

### 1. Metrics Configuration (`config/metrics.js`)

```javascript
const { createMetrics } = require('@demo-platform/queue-manager-core');

let metricsManager = null;

function initMetrics(getQueueLength, getActiveSessionCount) {
  metricsManager = createMetrics({
    serviceName: 'github-demo-queue-manager',  // Change this
    getQueueLength,
    getActiveSessionCount
  });
}

function getTracer() {
  return metricsManager ? metricsManager.getTracer() : null;
}

module.exports = {
  initMetrics,
  getTracer,
  get sessionsStartedCounter() { return metricsManager?.sessionsStarted; },
  get sessionsEndedCounter() { return metricsManager?.sessionsEnded; },
  get sessionDurationHistogram() { return metricsManager?.sessionDuration; },
  get queueWaitHistogram() { return metricsManager?.queueWait; },
  get ttydSpawnHistogram() { return metricsManager?.ttydSpawn; },
  get invitesValidatedCounter() { return metricsManager?.invitesValidated; }
};
```

### 2. Session Management (`services/session.js`)

```javascript
const {
  generateSessionToken: coreGenerateToken,
  createSessionEnvFile: coreCreateEnvFile
} = require('@demo-platform/queue-manager-core');

function generateSessionToken(sessionId) {
  return coreGenerateToken(sessionId, config.SESSION_SECRET);
}

function createSessionEnvFile(sessionId) {
  // API-specific environment variables
  const envVars = {
    GITHUB_TOKEN: config.GITHUB_TOKEN,
    GITHUB_ORG: config.GITHUB_ORG,
    // Add your API-specific vars here
    ...(config.CLAUDE_CODE_OAUTH_TOKEN && { CLAUDE_CODE_OAUTH_TOKEN: config.CLAUDE_CODE_OAUTH_TOKEN }),
    ...(config.ANTHROPIC_API_KEY && { ANTHROPIC_API_KEY: config.ANTHROPIC_API_KEY }),
  };

  return coreCreateEnvFile(sessionId, envVars, {
    containerPath: config.SESSION_ENV_CONTAINER_PATH,
    hostPath: config.SESSION_ENV_HOST_PATH
  });
}
```

### 3. Rate Limiting (`handlers/websocket.js`, `services/invite.js`)

```javascript
const { createConnectionRateLimiter } = require('@demo-platform/queue-manager-core');

const connectionRateLimiter = createConnectionRateLimiter({
  windowMs: config.RATE_LIMIT_WINDOW_MS,
  maxConnections: config.RATE_LIMIT_MAX_CONNECTIONS
});

function checkConnectionRateLimit(ip) {
  return connectionRateLimiter.check(ip);
}

function cleanupRateLimits() {
  connectionRateLimiter.cleanup();
}
```

### 4. Invite Rate Limiting (`services/invite.js`)

```javascript
const { createInviteRateLimiter } = require('@demo-platform/queue-manager-core');

const inviteRateLimiter = createInviteRateLimiter({
  windowMs: config.INVITE_RATE_LIMIT_WINDOW_MS,
  maxAttempts: config.INVITE_RATE_LIMIT_MAX_ATTEMPTS
});

function checkInviteRateLimit(ip) {
  return inviteRateLimiter.check(ip, false);
}

function recordFailedInviteAttempt(ip) {
  inviteRateLimiter.recordFailure(ip);
}
```

## Configuration Constants

Define these in `config/index.js`:

```javascript
module.exports = {
  // Server
  PORT: parseInt(process.env.PORT) || 3000,
  TTYD_PORT: parseInt(process.env.TTYD_PORT) || 7681,

  // Session
  SESSION_SECRET: process.env.SESSION_SECRET || 'change-me-in-production',
  SESSION_TIMEOUT_MINUTES: parseInt(process.env.SESSION_TIMEOUT_MINUTES) || 60,
  DISCONNECT_GRACE_MS: parseInt(process.env.DISCONNECT_GRACE_MS) || 30000,

  // Queue
  MAX_QUEUE_SIZE: parseInt(process.env.MAX_QUEUE_SIZE) || 10,

  // Rate limiting
  RATE_LIMIT_WINDOW_MS: 60 * 1000,
  RATE_LIMIT_MAX_CONNECTIONS: 10,
  INVITE_RATE_LIMIT_WINDOW_MS: 60 * 60 * 1000,
  INVITE_RATE_LIMIT_MAX_ATTEMPTS: 10,

  // Paths
  SESSION_ENV_CONTAINER_PATH: process.env.SESSION_ENV_CONTAINER_PATH || '/tmp/session-env',
  SESSION_ENV_HOST_PATH: process.env.SESSION_ENV_HOST_PATH || '/tmp/session-env',
  SCENARIOS_PATH: process.env.SCENARIOS_PATH || '/workspace/scenarios',

  // API-specific (customize these)
  GITHUB_TOKEN: process.env.GITHUB_TOKEN,
  GITHUB_ORG: process.env.GITHUB_ORG,

  // Claude
  CLAUDE_CODE_OAUTH_TOKEN: process.env.CLAUDE_CODE_OAUTH_TOKEN,
  ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,

  // Audit
  AUDIT_RETENTION_DAYS: parseInt(process.env.AUDIT_RETENTION_DAYS) || 90,

  // Security
  ALLOWED_ORIGINS: (process.env.ALLOWED_ORIGINS || process.env.BASE_URL || 'http://localhost:8080').split(','),
};
```

## Using Docker/Makefile Includes

### Docker Compose Fragments

Include shared fragments in your `docker-compose.yml`:

```yaml
# Note: Docker Compose doesn't support external includes natively
# Copy the anchor definitions or use extends

x-container-security: &container-security
  security_opt:
    - no-new-privileges:true
  cap_drop:
    - ALL
  cap_add:
    - CHOWN
    - SETUID
    - SETGID
    - DAC_OVERRIDE
  read_only: true

x-logging-standard: &logging-standard
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  queue-manager:
    <<: *container-security
    logging: *logging-standard
```

### Makefile Includes

Include shared Makefile targets:

```makefile
# Project-specific variables
PROJECT_NAME := github-demo
COMPOSE_FILE := docker-compose.yml
COMPOSE_DEV_FILE := docker-compose.dev.yml
REDIS_SERVICE := redis
BASE_URL := http://localhost:8080

# Include shared targets
include ../demo-platform-shared/makefile-includes/common.mk
include ../demo-platform-shared/makefile-includes/invites.mk
include ../demo-platform-shared/makefile-includes/skill-testing.mk

# Project-specific targets
.PHONY: custom-target
custom-target:
	@echo "Custom operation"
```

## Security Checklist

- [ ] Session tokens use HMAC-SHA256 signatures
- [ ] Rate limiting on WebSocket connections (10/min default)
- [ ] Brute-force protection on invite validation (10 failures/hour)
- [ ] Secure env files with 0600 permissions
- [ ] Container security constraints (memory, CPU, PID limits)
- [ ] Capabilities dropped (ALL dropped, minimal added back)
- [ ] Read-only filesystem with tmpfs mounts
- [ ] Path traversal protection on scenario routes
- [ ] Origin validation on WebSocket connections
- [ ] Hard timeout for zombie process prevention

## Testing

Verify your setup:

```bash
# Test module loading
cd queue-manager
node -e "
const config = require('./config');
console.log('✓ config loaded');
const metrics = require('./config/metrics');
console.log('✓ metrics loaded');
const session = require('./services/session');
console.log('✓ session loaded');
console.log('All modules loaded successfully!');
"

# Run shared library tests
cd ../demo-platform-shared/packages/queue-manager-core
npm test

# Start the dev environment
cd ../../github-demo
make dev
```

## Updating the Shared Library

When you need to add functionality to the shared library:

1. Make changes in `demo-platform-shared/packages/queue-manager-core/lib/`
2. Add tests in `demo-platform-shared/packages/queue-manager-core/test/`
3. Run tests: `npm test`
4. Update consuming projects: `npm install` in each queue-manager directory
5. Test all three demos still work

## Common Gotchas

1. **Path to shared library**: Ensure `package.json` has the correct relative path
2. **Missing config values**: All API-specific config must be in `config/index.js`
3. **Env file paths**: Both `containerPath` and `hostPath` must be configured
4. **Rate limit cleanup**: Call `cleanupRateLimits()` periodically (every 5 min)
5. **Metrics initialization**: Call `initMetrics()` before starting the server
