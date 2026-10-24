const test = require('node:test');
const assert = require('node:assert');
const { add, greet } = require('./app');

test('add returns the sum', () => {
  assert.strictEqual(add(2, 3), 5);
});

test('greet returns a greeting', () => {
  assert.strictEqual(greet('Murali'), 'Hello, Murali!');
});
