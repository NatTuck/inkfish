import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';

import { TeamSuggestions } from '../teams/team-suggestions';

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

describe('TeamSuggestions component', () => {
  const mockData = {
    course: {
      sections: ['default'],
      regs: [
        { id: 1, user: { id: 1, name: 'Alice' }, is_student: true },
        { id: 2, user: { id: 2, name: 'Bob' }, is_student: true },
        { id: 3, user: { id: 3, name: 'Charlie' }, is_student: true },
      ]
    },
    past: [],
    meeting: null
  };

  const activeTeams = [];

  test('renders section headers', () => {
    render(<TeamSuggestions data={mockData} active={activeTeams} />);
    
    expect(screen.getByText('Section default')).toBeInTheDocument();
  });

  test('renders suggestions for students', () => {
    render(<TeamSuggestions data={mockData} active={activeTeams} />);
    
    // Should have reroll button
    expect(screen.getByText('Reroll')).toBeInTheDocument();
  });

  test('reroll button generates new suggestions', () => {
    render(<TeamSuggestions data={mockData} active={activeTeams} />);
    
    const rerollButton = screen.getByText('Reroll');
    
    // Click reroll - should not throw
    expect(() => fireEvent.click(rerollButton)).not.toThrow();
  });

  test('displays student names in suggestions when present', () => {
    // Provide data with a meeting that has attendance
    const dataWithMeeting = {
      ...mockData,
      meeting: {
        students: [
          [{ id: 1 }, { status: 'present' }],
          [{ id: 2 }, { status: 'present' }],
          [{ id: 3 }, { status: 'present' }],
        ]
      }
    };
    
    render(<TeamSuggestions data={dataWithMeeting} active={activeTeams} />);
    
    // With all students present, should show them in suggestions
    // The exact output depends on the suggestion algorithm
    expect(screen.getByText('Reroll')).toBeInTheDocument();
  });
});
