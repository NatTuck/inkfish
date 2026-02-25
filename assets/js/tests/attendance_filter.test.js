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

describe('attendance filtering', () => {
  describe('filterStudentsByAttendance', () => {
    function filterStudentsByAttendance(regs, attendanceMap) {
      const presentIds = new global.Set();
      
      if (attendanceMap) {
        for (const [reg, att] of attendanceMap) {
          if (att && (att.status === 'present' || att.status === 'late' || att.status === 'on time')) {
            presentIds.add(reg.id);
          }
        }
      }
      
      return regs.filter(reg => presentIds.has(reg.id));
    }

    test('includes present students', () => {
      const regs = [
        { id: 1, name: 'Alice' },
        { id: 2, name: 'Bob' },
        { id: 3, name: 'Charlie' }
      ];
      
      const attendances = [
        [{ id: 1 }, { status: 'present' }],
        [{ id: 2 }, null],
        [{ id: 3 }, { status: 'late' }]
      ];
      
      const result = filterStudentsByAttendance(regs, attendances);
      
      expect(result.map(r => r.id)).toEqual([1, 3]);
    });

    test('excludes absent students', () => {
      const regs = [
        { id: 1, name: 'Alice' },
        { id: 2, name: 'Bob' }
      ];
      
      const attendances = [
        [{ id: 1 }, { status: 'present' }],
        [{ id: 2 }, null]
      ];
      
      const result = filterStudentsByAttendance(regs, attendances);
      
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe(1);
    });

    test('returns empty when no students present', () => {
      const regs = [
        { id: 1, name: 'Alice' },
        { id: 2, name: 'Bob' }
      ];
      
      const attendances = [
        [{ id: 1 }, null],
        [{ id: 2 }, null]
      ];
      
      const result = filterStudentsByAttendance(regs, attendances);
      
      expect(result).toHaveLength(0);
    });

    test('includes all students when all present', () => {
      const regs = [
        { id: 1, name: 'Alice' },
        { id: 2, name: 'Bob' },
        { id: 3, name: 'Charlie' }
      ];
      
      const attendances = [
        [{ id: 1 }, { status: 'present' }],
        [{ id: 2 }, { status: 'on time' }],
        [{ id: 3 }, { status: 'late' }]
      ];
      
      const result = filterStudentsByAttendance(regs, attendances);
      
      expect(result).toHaveLength(3);
      expect(result.map(r => r.id)).toEqual([1, 2, 3]);
    });
  });

  describe('suggest with attendance integration', () => {
    test('generates suggestions for present students only', () => {
      const regs = [
        { id: 1, user: { id: 1, name: 'Alice' } },
        { id: 2, user: { id: 2, name: 'Bob' } },
        { id: 3, user: { id: 3, name: 'Charlie' } }
      ];
      
      const attendances = [
        [{ id: 1 }, { status: 'present' }],
        [{ id: 2 }, null],
        [{ id: 3 }, { status: 'present' }]
      ];
      
      // Filter to present students
      const presentIds = new global.Set();
      for (const [reg, att] of attendances) {
        if (att) presentIds.add(reg.id);
      }
      
      const presentStudents = regs
        .filter(reg => presentIds.has(reg.user.id))
        .map(reg => reg.user.id);
      
      // Generate suggestions for present students only
      const suggestions = suggest_pairs(presentStudents, Map());
      
      // Should only include present students (1 and 3)
      const allStudents = [];
      suggestions.forEach(team => {
        allStudents.push(...team.toJS());
      });
      
      expect(allStudents.sort()).toEqual([1, 3]);
    });
  });
});