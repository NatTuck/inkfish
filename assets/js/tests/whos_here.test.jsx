import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

import { WhosHere } from '../teams/team-manager';

describe('WhosHere component', () => {
  test('renders "no meeting" when no meeting', () => {
    render(<WhosHere meeting={null} />);
    
    expect(screen.getByText('No active meeting.')).toBeInTheDocument();
  });

  test('renders student as "here" when present', () => {
    const meeting = {
      secret_code: 'ABC123',
      students: [
        [{ id: 1, user: { name: 'Alice' } }, { status: 'present' }],
        [{ id: 2, user: { name: 'Bob' } }, { status: 'late' }],
      ]
    };
    
    render(<WhosHere meeting={meeting} />);
    
    expect(screen.getByText('Alice')).toBeInTheDocument();
    expect(screen.getByText('Bob')).toBeInTheDocument();
    expect(screen.getAllByText('here')).toHaveLength(2);
  });

  test('renders student as "missing" when absent', () => {
    const meeting = {
      secret_code: 'ABC123',
      students: [
        [{ id: 1, user: { name: 'Alice' } }, { status: 'present' }],
        [{ id: 2, user: { name: 'Bob' } }, null],
      ]
    };
    
    render(<WhosHere meeting={meeting} />);
    
    expect(screen.getByText('Alice')).toBeInTheDocument();
    expect(screen.getByText('Bob')).toBeInTheDocument();
    expect(screen.getByText('missing')).toBeInTheDocument();
  });

  test('renders secret code', () => {
    const meeting = {
      secret_code: 'SECRET123',
      students: []
    };
    
    render(<WhosHere meeting={meeting} />);
    
    expect(screen.getByText('Code: SECRET123')).toBeInTheDocument();
  });
});
