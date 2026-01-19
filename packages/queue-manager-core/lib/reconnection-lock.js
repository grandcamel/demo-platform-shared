/**
 * Reconnection lock utility for demo platform queue managers.
 *
 * Provides atomic lock operations to prevent race conditions during
 * WebSocket reconnection handling.
 */

/**
 * Create a reconnection lock instance.
 *
 * The lock ensures that only one reconnection attempt can be processed
 * at a time, preventing race conditions when multiple reconnection
 * events occur in rapid succession.
 *
 * @returns {Object} Reconnection lock instance
 *
 * @example
 * const lock = createReconnectionLock();
 *
 * // Check if reconnection is already in progress
 * if (lock.isLocked()) {
 *   console.log('Reconnection already in progress');
 *   return;
 * }
 *
 * // Acquire lock before processing
 * if (!lock.acquire()) {
 *   console.log('Could not acquire lock');
 *   return;
 * }
 *
 * try {
 *   // Process reconnection
 *   await handleReconnection();
 * } finally {
 *   lock.release();
 * }
 */
function createReconnectionLock() {
  let locked = false;

  /**
   * Check if the lock is currently held.
   *
   * @returns {boolean} True if locked
   */
  function isLocked() {
    return locked;
  }

  /**
   * Attempt to acquire the lock.
   *
   * This is an atomic operation - if the lock is already held,
   * this returns false immediately without blocking.
   *
   * @returns {boolean} True if lock was acquired, false if already locked
   */
  function acquire() {
    if (locked) {
      return false;
    }
    locked = true;
    return true;
  }

  /**
   * Release the lock.
   *
   * This is idempotent - calling release when not locked is a no-op.
   */
  function release() {
    locked = false;
  }

  /**
   * Execute a function while holding the lock.
   *
   * If the lock cannot be acquired, the function is not executed
   * and null is returned.
   *
   * @param {Function} fn - Function to execute (can be async)
   * @returns {Promise<*>|null} Result of fn, or null if lock not acquired
   *
   * @example
   * const result = await lock.withLock(async () => {
   *   await processReconnection();
   *   return 'success';
   * });
   * if (result === null) {
   *   console.log('Could not process - reconnection in progress');
   * }
   */
  async function withLock(fn) {
    if (!acquire()) {
      return null;
    }
    try {
      return await fn();
    } finally {
      release();
    }
  }

  return {
    isLocked,
    acquire,
    release,
    withLock
  };
}

module.exports = {
  createReconnectionLock
};
