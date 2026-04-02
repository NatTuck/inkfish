import { suggest_pairs } from '../teams/team-suggestions';
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

describe('suggest_pairs', () => {
  test('returns empty array for empty students', () => {
    const result = suggest_pairs([], Map());
    expect(result).toEqual([]);
  });

  test('returns single team for one student', () => {
    const students = [1];
    const result = suggest_pairs(students, Map());
    expect(result.length).toBe(1);
    expect(result[0].toJS()).toEqual([1]);
  });

  test('returns single team for two students', () => {
    const students = [1, 2];
    const result = suggest_pairs(students, Map());
    expect(result.length).toBe(1);
    expect(result[0].toJS().sort()).toEqual([1, 2]);
  });

  test('returns teams covering all students for three students', () => {
    const students = [1, 2, 3];
    const result = suggest_pairs(students, Map());
    expect(result.length).toBe(2);
    const allStudents = [];
    result.forEach(team => {
      allStudents.push(...team.toJS());
    });
    expect(allStudents.sort()).toEqual([1, 2, 3]);
  });

  test('avoids past teams when possible', () => {
    const students = [1, 2, 3];
    const pastTeams = Map().set(Set([1, 2]), 1);
    const result = suggest_pairs(students, pastTeams);
    const team1 = result[0];
    const team1Array = team1.toJS();
    const has1and2 = team1Array.includes(1) && team1Array.includes(2);
    expect(has1and2).toBe(false);
  });

  test('each team has at most two students', () => {
    const students = [1, 2, 3, 4, 5];
    const result = suggest_pairs(students, Map());
    result.forEach(team => {
      expect(team.size).toBeLessThanOrEqual(2);
    });
  });
});
