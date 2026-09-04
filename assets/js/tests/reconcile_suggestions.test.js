import { reconcile_suggestions } from '../teams/team-suggestions';
import { Set, Map } from 'immutable';

jest.mock('lodash', () => ({
  shuffle: (arr) => arr,
  drop: (arr, n) => arr.slice(n),
  minBy: (arr, fn) => {
    let minItem = arr[0];
    let minVal = fn(minItem);
    for (const item of arr) {
      const val = fn(item);
      if (val < minVal) {
        minVal = val;
        minItem = item;
      }
    }
    return minItem;
  },
  filter: (arr, fn) => arr.filter(fn),
}));

describe('reconcile_suggestions', () => {
  test('adds newly eligible students', () => {
    const pairs = [Set([1, 2])];
    const result = reconcile_suggestions(pairs, [1, 2, 3], Map());
    expect(result.length).toBe(2);
    const all = result.flatMap(p => p.toArray()).sort();
    expect(all).toEqual([1, 2, 3]);
  });

  test('prunes a student who becomes busy', () => {
    const pairs = [Set([1, 2]), Set([3, 4])];
    // Student 2 is now on a team (no longer eligible).
    const result = reconcile_suggestions(pairs, [1, 3, 4], Map());
    const ids = result.flatMap(p => p.toArray());
    expect(ids).not.toContain(2);
    expect(ids.sort()).toEqual([1, 3, 4]);
  });

  test('removes empty pairs entirely', () => {
    const pairs = [Set([1, 2])];
    const result = reconcile_suggestions(pairs, [], Map());
    expect(result).toEqual([]);
  });

  test('leaves full coverage pairs untouched', () => {
    const pairs = [Set([1, 2]), Set([3])];
    const result = reconcile_suggestions(pairs, [1, 2, 3], Map());
    expect(result.length).toBe(2);
    expect(result[0].toArray().sort()).toEqual([1, 2]);
    expect(result[1].toArray().sort()).toEqual([3]);
  });

  test('does not re-pair with a forbidden past team', () => {
    // 1 and 2 have already been on a team together.
    const pastTeams = Map().set(Set([1, 2]), 1);
    const pairs = [Set([3]), Set([4])];
    // New student 1 arrives; it must not join 3 if (1,3) is fine it will,
    // but it should never end up back with 2 when 2 isn't even eligible.
    const result = reconcile_suggestions(pairs, [1, 2, 3, 4], pastTeams);
    const has1and2 = result.some(p =>
      p.has(1) && p.has(2)
    );
    expect(has1and2).toBe(false);
  });
});
