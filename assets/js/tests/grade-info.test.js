import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { GradeInfo } from '../code-view/file-tree';

describe('GradeInfo', () => {
  const baseGrade = {
    id: 1,
    confirmed: false,
    score: null,
    preview_score: '35.0',
    grade_column: {
      base: '40.0',
      points: '50.0',
    },
    line_comments: [
      { points: '-5.0' },
    ],
    sub: {
      team: {
        regs: [
          { user: { name: 'Alice' } },
        ],
      },
      reg: {
        user: { name: 'Alice' },
      },
    },
  };

  test('shows Draft badge when unconfirmed', () => {
    const grade = { ...baseGrade, confirmed: false };
    render(<GradeInfo grade={grade} />);
    
    expect(screen.getByText('Draft')).toBeInTheDocument();
  });

  test('shows Confirmed badge when confirmed', () => {
    const grade = { ...baseGrade, confirmed: true, score: '35.0' };
    render(<GradeInfo grade={grade} />);
    
    expect(screen.getByText('Confirmed')).toBeInTheDocument();
  });

  test('shows preview score when unconfirmed', () => {
    const grade = { ...baseGrade, confirmed: false, score: null, preview_score: '35.0' };
    render(<GradeInfo grade={grade} />);
    
    expect(screen.getByText(/preview: 35.0/)).toBeInTheDocument();
  });

  test('shows actual score when confirmed', () => {
    const grade = { ...baseGrade, confirmed: true, score: '35.0', preview_score: null };
    render(<GradeInfo grade={grade} />);
    
    expect(screen.getByText(/Total: 35.0/)).toBeInTheDocument();
  });

  test('shows -- when score is null and confirmed', () => {
    const grade = { ...baseGrade, confirmed: true, score: null };
    render(<GradeInfo grade={grade} />);
    
    expect(screen.getByText(/Total: --/)).toBeInTheDocument();
  });

  test('calculates comment sum correctly', () => {
    const grade = {
      ...baseGrade,
      line_comments: [
        { points: '-5.0' },
        { points: '-3.0' },
      ],
    };
    render(<GradeInfo grade={grade} />);
    
    expect(screen.getByText('Comments: 2 (-8)')).toBeInTheDocument();
  });
});