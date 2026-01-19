/**
 * Tests for rate limiting utilities.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const {
  createRateLimiter,
  createConnectionRateLimiter,
  createInviteRateLimiter
} = require('../lib/rate-limit');

describe('createRateLimiter', () => {
  it('allows requests within limit', () => {
    const limiter = createRateLimiter({
      windowMs: 60000,
      maxAttempts: 3
    });

    const result1 = limiter.check('ip-1');
    assert.strictEqual(result1.allowed, true);
    assert.strictEqual(result1.remaining, 2);

    const result2 = limiter.check('ip-1');
    assert.strictEqual(result2.allowed, true);
    assert.strictEqual(result2.remaining, 1);

    const result3 = limiter.check('ip-1');
    assert.strictEqual(result3.allowed, true);
    assert.strictEqual(result3.remaining, 0);
  });

  it('blocks requests exceeding limit', () => {
    const limiter = createRateLimiter({
      windowMs: 60000,
      maxAttempts: 2
    });

    limiter.check('ip-2');
    limiter.check('ip-2');

    const result = limiter.check('ip-2');
    assert.strictEqual(result.allowed, false);
    assert.ok(result.retryAfter > 0);
  });

  it('tracks different keys independently', () => {
    const limiter = createRateLimiter({
      windowMs: 60000,
      maxAttempts: 1
    });

    limiter.check('ip-a');
    const resultA = limiter.check('ip-a');
    assert.strictEqual(resultA.allowed, false);

    const resultB = limiter.check('ip-b');
    assert.strictEqual(resultB.allowed, true);
  });

  it('reset clears rate limit for a key', () => {
    const limiter = createRateLimiter({
      windowMs: 60000,
      maxAttempts: 1
    });

    limiter.check('ip-reset');
    const blocked = limiter.check('ip-reset');
    assert.strictEqual(blocked.allowed, false);

    limiter.reset('ip-reset');

    const afterReset = limiter.check('ip-reset');
    assert.strictEqual(afterReset.allowed, true);
  });
});

describe('createConnectionRateLimiter', () => {
  it('creates limiter with default values', () => {
    const limiter = createConnectionRateLimiter();
    assert.ok(typeof limiter.check === 'function');
    assert.ok(typeof limiter.cleanup === 'function');
  });

  it('accepts custom options', () => {
    const limiter = createConnectionRateLimiter({
      maxConnections: 5
    });

    for (let i = 0; i < 5; i++) {
      const result = limiter.check('test-ip');
      assert.strictEqual(result.allowed, true);
    }

    const blocked = limiter.check('test-ip');
    assert.strictEqual(blocked.allowed, false);
  });
});

describe('createInviteRateLimiter', () => {
  it('creates limiter with default values', () => {
    const limiter = createInviteRateLimiter();
    assert.ok(typeof limiter.check === 'function');
    assert.ok(typeof limiter.recordFailure === 'function');
  });
});
