// The suites are supposed to be quiet: any console output from the code under
// test is either debug logging that should be removed or an error a test
// should assert. This records every call and fails the test that made it, so a
// stray `console.log` cannot creep back in unnoticed.
const METHODS = ['log', 'info', 'warn', 'error', 'debug'];

let calls = [];

// A test that provokes output on purpose asserts it rather than tripping the
// trap: whatever the callback records is returned and marked as accounted for.
// This is the JS side of the Elixir rule "keep the log, capture and assert it"
// -- without it, the only way to test an error path that logs would be to
// delete the log.
//
// `await` the result when the callback is async, or the assertion runs after
// the test has already finished.
global.expectConsole = (fn) => {
  calls = [];

  const take = () => {
    const recorded = calls;
    calls = [];
    return recorded;
  };

  const result = fn();

  return result && typeof result.then === 'function'
    ? result.then(take)
    : take();
};

beforeEach(() => {
  calls = [];

  METHODS.forEach((method) => {
    jest.spyOn(console, method).mockImplementation((...args) => {
      calls.push({ method, args });
    });
  });
});

afterEach(() => {
  const recorded = calls;
  calls = [];
  jest.restoreAllMocks();

  if (recorded.length === 0) {
    return;
  }

  const lines = recorded.map(
    ({ method, args }) =>
      `console.${method}(${args.map((arg) => String(arg)).join(' ')})`
  );

  throw new Error(
    'console output during test (assert it with expectConsole(...)):\n  ' +
      lines.join('\n  ')
  );
});
