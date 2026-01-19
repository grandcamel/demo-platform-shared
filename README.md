# Demo Platform Shared

Shared libraries, Docker fragments, and Makefile includes for demo platform projects (jira-demo, confluence-demo, splunk-demo).

## Overview

This repository provides common functionality extracted from multiple demo platforms to reduce code duplication and ensure consistent behavior across projects.

## Structure

```
demo-platform-shared/
├── packages/
│   └── queue-manager-core/     # Node.js shared library
│       ├── lib/
│       │   ├── index.js        # Main exports
│       │   ├── session.js      # Session token generation/validation
│       │   ├── rate-limit.js   # Rate limiting utilities
│       │   ├── env-file.js     # Secure env file management
│       │   └── metrics.js      # OpenTelemetry metrics
│       ├── test/               # Unit tests
│       └── package.json
├── docker/
│   └── compose-fragments/      # Reusable Docker Compose anchors
│       ├── security-constraints.yml
│       ├── logging.yml
│       └── healthcheck.yml
├── makefile-includes/          # Reusable Makefile targets
│   ├── common.mk               # Dev/deploy targets
│   ├── skill-testing.mk        # Skill test targets
│   └── invites.mk              # Invite management
└── docs/
    └── CREATING-NEW-DEMOS.md   # Guide for new demos
```

## Quick Start

### Using the Node.js Library

Add to your `package.json`:

```json
{
  "dependencies": {
    "@demo-platform/queue-manager-core": "file:../../demo-platform-shared/packages/queue-manager-core"
  }
}
```

Then:

```javascript
const {
  generateSessionToken,
  validateSessionToken,
  createSessionEnvFile,
  createConnectionRateLimiter,
  createInviteRateLimiter,
  createMetrics
} = require('@demo-platform/queue-manager-core');
```

### Using Makefile Includes

```makefile
PROJECT_NAME := my-demo
include ../demo-platform-shared/makefile-includes/common.mk
```

## Shared Library API

### Session Tokens

```javascript
// Generate a session token
const token = generateSessionToken(sessionId, secret);

// Validate a session token
const result = validateSessionToken(token, secret, { maxAgeMs: 3600000 });
// { valid: true, sessionId: '...', timestamp: 1234567890 }
// or { valid: false, error: 'Token expired' }
```

### Rate Limiting

```javascript
// Connection rate limiter
const limiter = createConnectionRateLimiter({
  windowMs: 60000,      // 1 minute window
  maxConnections: 10    // Max 10 connections per IP
});

const result = limiter.check(ip);
// { allowed: true } or { allowed: false, retryAfter: 45 }

// Invite rate limiter (for brute-force protection)
const inviteLimiter = createInviteRateLimiter({
  windowMs: 3600000,    // 1 hour window
  maxAttempts: 10       // Max 10 failed attempts
});

inviteLimiter.recordFailure(ip);
const result = inviteLimiter.check(ip);
```

### Secure Environment Files

```javascript
const envFile = createSessionEnvFile(sessionId, {
  API_TOKEN: 'secret-token',
  API_URL: 'https://api.example.com'
}, {
  containerPath: '/tmp/session-env',
  hostPath: '/var/session-env'
});

// { containerPath: '...', hostPath: '...', cleanup: Function }

// Clean up when session ends
envFile.cleanup();
```

### OpenTelemetry Metrics

```javascript
const metricsManager = createMetrics({
  serviceName: 'my-demo-queue-manager',
  getQueueLength: () => queue.length,
  getActiveSessionCount: () => session ? 1 : 0
});

// Access metrics
metricsManager.sessionsStarted.add(1);
metricsManager.sessionDuration.record(durationSeconds, { reason: 'timeout' });

// Get tracer for distributed tracing
const tracer = metricsManager.getTracer();
```

## Docker Compose Fragments

### Security Constraints

```yaml
# Reference in your docker-compose.yml:
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
```

### Logging

```yaml
x-logging-standard: &logging-standard
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

## Makefile Includes

### common.mk

Provides: `dev`, `dev-down`, `deploy`, `logs`, `health`, `clean`, `redis-cli`, `lint`

### invites.mk

Provides: `invite`, `invite-local`, `invite-list`, `invite-revoke`, `invite-cleanup`

### skill-testing.mk

Provides: `test-skill`, `test-skill-mock`, `test-skill-dev`, `refine-skill`, `list-scenarios`

## Testing

```bash
cd packages/queue-manager-core
npm test
```

## Projects Using This Library

| Project | Description |
|---------|-------------|
| [jira-demo](https://github.com/grandcamel/jira-demo) | JIRA Assistant Skills demo |
| [confluence-demo](https://github.com/grandcamel/confluence-demo) | Confluence Assistant Skills demo |
| [splunk-demo](https://github.com/grandcamel/splunk-demo) | Splunk Assistant Skills demo |

## Creating New Demos

See [docs/CREATING-NEW-DEMOS.md](docs/CREATING-NEW-DEMOS.md) for a complete guide.

## Contributing

1. Make changes in the appropriate package
2. Add tests for new functionality
3. Run tests: `npm test`
4. Update all consuming projects and verify they still work
5. Submit a PR

## License

MIT
