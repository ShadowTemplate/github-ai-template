import { test } from 'node:test';
import assert from 'node:assert/strict';
import { greet, farewell } from '../src/index.js';

test('greet returns a greeting', () => {
  assert.equal(greet('world'), 'Hello, world!');
});

test('farewell returns a farewell', () => {
  assert.equal(farewell('world'), 'Bye bye,world!');
});
