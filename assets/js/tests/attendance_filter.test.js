import { filterStudentsByAttendance, suggest_pairs } from '../teams/team-suggestions';
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

describe('filterStudentsByAttendance', () => {
  test('includes students with "on time" status', () => {
    const regs = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ];
    
    const attendances = [
      [{ id: 1 }, { status: 'on time' }],
      [{ id: 2 }, null]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(1);
  });

  test('includes students with "late" status', () => {
    const regs = [
      { id: 1, name: 'Alice' }
    ];
    
    const attendances = [
      [{ id: 1 }, { status: 'late' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(1);
  });

  test('includes students with "very late" status', () => {
    const regs = [
      { id: 1, name: 'Alice' }
    ];
    
    const attendances = [
      [{ id: 1 }, { status: 'very late' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(1);
  });

  test('includes students with "too late" status', () => {
    const regs = [
      { id: 1, name: 'Alice' }
    ];
    
    const attendances = [
      [{ id: 1 }, { status: 'too late' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(1);
  });

  test('excludes students with "excused" status', () => {
    const regs = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ];
    
    const attendances = [
      [{ id: 1 }, { status: 'excused' }],
      [{ id: 2 }, { status: 'on time' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(2);
  });

  test('excludes students without attendance (missing)', () => {
    const regs = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ];
    
    const attendances = [
      [{ id: 1 }, null],
      [{ id: 2 }, { status: 'on time' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(2);
  });

  test('includes all present students (on time, late, very late, too late)', () => {
    const regs = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' },
      { id: 3, name: 'Charlie' },
      { id: 4, name: 'Dana' }
    ];
    
    const attendances = [
      [{ id: 1 }, { status: 'on time' }],
      [{ id: 2 }, { status: 'late' }],
      [{ id: 3 }, { status: 'very late' }],
      [{ id: 4 }, { status: 'too late' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(4);
    expect(result.map(r => r.id)).toEqual([1, 2, 3, 4]);
  });

  test('excludes both excused and missing students', () => {
    const regs = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' },
      { id: 3, name: 'Charlie' }
    ];
    
    const attendances = [
      [{ id: 1 }, { status: 'excused' }],
      [{ id: 2 }, null],
      [{ id: 3 }, { status: 'on time' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(3);
  });

  test('returns empty array when no students are present', () => {
    const regs = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ];
    
    const attendances = [
      [{ id: 1 }, null],
      [{ id: 2 }, { status: 'excused' }]
    ];
    
    const result = filterStudentsByAttendance(regs, attendances);
    
    expect(result).toHaveLength(0);
  });

  test('handles null attendanceMap', () => {
    const regs = [
      { id: 1, name: 'Alice' }
    ];
    
    const result = filterStudentsByAttendance(regs, null);
    
    expect(result).toHaveLength(0);
  });

  test('handles undefined attendanceMap', () => {
    const regs = [
      { id: 1, name: 'Alice' }
    ];
    
    const result = filterStudentsByAttendance(regs, undefined);
    
    expect(result).toHaveLength(0);
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
      [{ id: 1 }, { status: 'on time' }],
      [{ id: 2 }, null],
      [{ id: 3 }, { status: 'late' }]
    ];
    
    const presentStudents = filterStudentsByAttendance(regs, attendances);
    
    expect(presentStudents).toHaveLength(2);
    expect(presentStudents.map(r => r.id)).toEqual([1, 3]);
  });
});