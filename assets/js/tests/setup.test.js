// The trap in `setup.js` fails any test that leaves console output unaccounted
// for, so the way to test code that logs is `expectConsole`. This checks that
// helper actually hands the calls back -- and, because this file runs under the
// same trap, that accounting for them is enough to keep the suite quiet.
test('expectConsole returns the calls it accounted for', () => {
  const calls = expectConsole(() => {
    console.log('debug line');
    console.error('real failure', {code: 7});
  });

  expect(calls).toHaveLength(2);
  expect(calls[0].method).toBe('log');
  expect(calls[0].args).toEqual(['debug line']);
  expect(calls[1].method).toBe('error');
  expect(calls[1].args).toEqual(['real failure', {code: 7}]);
});

test('expectConsole returns an empty list when nothing was printed', () => {
  expect(expectConsole(() => {})).toEqual([]);
});
