import { add_new_students_to_suggestions, suggest_pairs } from '../teams/team-suggestions';
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

describe('add_new_students_to_suggestions', () => {
  describe('adding to existing teams of 1', () => {
    test('adds new student to first team of 1', () => {
      const prevPairs = [Set([1])];
      const newStudents = [2];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(1);
      expect(result[0]).toEqual(Set([1, 2]));
    });

    test('adds new student to first team of 1 when multiple teams exist', () => {
      const prevPairs = [Set([1]), Set([3]), Set([5])];
      const newStudents = [2];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(3);
      expect(result[0]).toEqual(Set([1, 2]));
      expect(result[1]).toEqual(Set([3]));
      expect(result[2]).toEqual(Set([5]));
    });
  });

  describe('avoiding repeat teams', () => {
    test('skips team of 1 that would create repeat team', () => {
      const prevPairs = [Set([1])];
      const newStudents = [2];
      const pastTeams = Map([[Set([1, 2]), 1]]);

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual(Set([1]));
      expect(result[1]).toEqual(Set([2]));
    });

    test('finds second team of 1 if first would create repeat', () => {
      const prevPairs = [Set([1]), Set([3])];
      const newStudents = [2];
      const pastTeams = Map([[Set([1, 2]), 1]]);

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual(Set([1]));
      expect(result[1]).toEqual(Set([3, 2]));
    });

    test('creates new team of 1 if all existing teams would create repeats', () => {
      const prevPairs = [Set([1]), Set([3])];
      const newStudents = [2];
      const pastTeams = Map([
        [Set([1, 2]), 1],
        [Set([3, 2]), 1]
      ]);

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(3);
      expect(result[0]).toEqual(Set([1]));
      expect(result[1]).toEqual(Set([3]));
      expect(result[2]).toEqual(Set([2]));
    });
  });

  describe('adding multiple students', () => {
    test('adds multiple new students one at a time, filling teams of 1', () => {
      const prevPairs = [Set([1])];
      const newStudents = [2, 3];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual(Set([1, 2]));
      expect(result[1]).toEqual(Set([3]));
    });

    test('each student is added sequentially, filling teams of 1', () => {
      const prevPairs = [];
      const newStudents = [1, 2, 3];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual(Set([1, 2]));
      expect(result[1]).toEqual(Set([3]));
    });

    test('fills teams of 1 before creating new teams', () => {
      const prevPairs = [Set([1]), Set([4])];
      const newStudents = [2, 3];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual(Set([1, 2]));
      expect(result[1]).toEqual(Set([4, 3]));
    });
  });

  describe('edge cases', () => {
    test('returns unchanged pairs when no new students', () => {
      const prevPairs = [Set([1, 2])];
      const newStudents = [];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toBe(prevPairs);
    });

    test('creates new team of 1 when no existing pairs', () => {
      const prevPairs = [];
      const newStudents = [1];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(1);
      expect(result[0]).toEqual(Set([1]));
    });

    test('does not modify teams of 2', () => {
      const prevPairs = [Set([1, 2])];
      const newStudents = [3];
      const pastTeams = Map();

      const result = add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual(Set([1, 2]));
      expect(result[1]).toEqual(Set([3]));
    });
  });
});