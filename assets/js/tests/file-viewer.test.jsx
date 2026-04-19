import '@testing-library/jest-dom';
import React from 'react';
import { render, screen } from '@testing-library/react';
import FileViewer from '../code-view/file-viewer.jsx';

describe('FileViewer', () => {
  const mockGrade = {
    id: 1,
    confirmed: false,
    preview_score: '40.0',
    line_comments: [],
  };

  const mockData = {
    files: {
      path: 'test.md',
      text: '# Hello World\n\nThis is a test file.',
      nodes: [],
    },
    text: '# Hello World\n\nThis is a test file.',
    path: 'test.md',
    grade: mockGrade,
    gradeConfirmed: false,
    comments: [],
    grader: { id: 1, name: 'Grader' },
  };

  test('renders markdown file with preview buttons', () => {
    const setGrade = jest.fn();
    render(
      <FileViewer
        path="test.md"
        data={mockData}
        grade={mockGrade}
        setGrade={setGrade}
      />
    );

    expect(screen.getByText('Preview')).toBeInTheDocument();
    expect(screen.getByText('Code')).toBeInTheDocument();
  });

  test('shows no file message when path is empty', () => {
    const emptyData = {
      ...mockData,
      files: { path: '', nodes: [] },
      path: '',
      text: '',
    };

    const setGrade = jest.fn();
    render(
      <FileViewer
        path=""
        data={emptyData}
        grade={mockGrade}
        setGrade={setGrade}
      />
    );

    expect(screen.getByText('Select a file from the list to the left.')).toBeInTheDocument();
  });

  test('Button component is properly imported and renders', () => {
    const setGrade = jest.fn();
    render(
      <FileViewer
        path="test.md"
        data={mockData}
        grade={mockGrade}
        setGrade={setGrade}
      />
    );

    const buttons = screen.getAllByRole('button');
    expect(buttons.length).toBe(2);
    expect(buttons[0]).toHaveTextContent('Preview');
    expect(buttons[1]).toHaveTextContent('Code');
  });

  test('handles file with existing line comments', () => {
    const gradeWithComments = {
      ...mockGrade,
      line_comments: [
        {
          id: 1,
          path: 'test.md',
          line: 1,
          points: '-5.0',
          text: 'Test comment',
          user: { id: 1, name: 'Grader' },
        },
      ],
    };

    const dataWithComments = {
      ...mockData,
      grade: gradeWithComments,
      comments: gradeWithComments.line_comments,
    };

    const setGrade = jest.fn();
    render(
      <FileViewer
        path="test.md"
        data={dataWithComments}
        grade={gradeWithComments}
        setGrade={setGrade}
      />
    );

    expect(screen.getByText('Preview')).toBeInTheDocument();
  });
});