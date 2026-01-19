/**
 * Tests for session token utilities.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const {
  generateSessionToken,
  validateSessionToken,
  isSessionTokenExpired
} = require('../lib/session');

describe('generateSessionToken', () => {
  it('generates a valid token format', () => {
    const token = generateSessionToken('test-session', 'secret');
    assert.ok(token.includes('.'), 'Token should contain a dot separator');

    const [data, signature] = token.split('.');
    assert.ok(data.length > 0, 'Data part should not be empty');
    assert.ok(signature.length === 64, 'Signature should be 64 hex characters');
  });

  it('throws on invalid sessionId', () => {
    assert.throws(() => generateSessionToken('', 'secret'));
    assert.throws(() => generateSessionToken(null, 'secret'));
  });

  it('throws on invalid secret', () => {
    assert.throws(() => generateSessionToken('session', ''));
    assert.throws(() => generateSessionToken('session', null));
  });
});

describe('validateSessionToken', () => {
  const secret = 'test-secret-key';

  it('validates a valid token', () => {
    const token = generateSessionToken('my-session', secret);
    const result = validateSessionToken(token, secret);

    assert.strictEqual(result.valid, true);
    assert.strictEqual(result.sessionId, 'my-session');
    assert.ok(result.timestamp > 0);
    assert.strictEqual(result.error, null);
  });

  it('rejects token with wrong secret', () => {
    const token = generateSessionToken('my-session', secret);
    const result = validateSessionToken(token, 'wrong-secret');

    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('signature'));
  });

  it('rejects malformed token', () => {
    const result = validateSessionToken('not-a-valid-token', secret);
    assert.strictEqual(result.valid, false);
  });

  it('rejects token with tampered data', () => {
    const token = generateSessionToken('my-session', secret);
    const [, signature] = token.split('.');
    const tamperedData = Buffer.from('tampered:12345').toString('base64');
    const tamperedToken = `${tamperedData}.${signature}`;

    const result = validateSessionToken(tamperedToken, secret);
    assert.strictEqual(result.valid, false);
  });
});

describe('isSessionTokenExpired', () => {
  const secret = 'test-secret';

  it('returns not expired for fresh token', () => {
    const token = generateSessionToken('session', secret);
    const result = isSessionTokenExpired(token, secret, 60 * 1000);

    assert.strictEqual(result.expired, false);
    assert.ok(result.ageMs < 1000);
  });

  it('handles invalid token', () => {
    const result = isSessionTokenExpired('invalid', secret, 60 * 1000);
    assert.strictEqual(result.expired, true);
    assert.ok(result.error);
  });
});
