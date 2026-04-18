import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import LineComment from '../code-view/line-comment';

jest.mock('react-bootstrap', () => {
  const CardMock = ({ children, className, style }) => (
    <div className={className} style={style} data-testid="card">{children}</div>
  );
  CardMock.Body = ({ children, className }) => (
    <div className={className} data-testid="card-body">{children}</div>
  );
  return {
    Card: CardMock,
    Row: ({ children }) => <div className="row">{children}</div>,
    Col: ({ children, sm, className }) => (
      <div className={`col-sm-${sm} ${className || ''}`.trim()}>{children}</div>
    ),
    Form: {
      Control: ({ type, value, onChange, disabled, rows, onKeyPress, as }) => (
        as === 'textarea' 
          ? <textarea value={value} onChange={onChange} disabled={disabled} rows={rows} data-testid="comment-text" />
          : <input type={type || 'text'} value={value} onChange={onChange} disabled={disabled} onKeyPress={onKeyPress} data-testid="comment-points" />
      ),
    },
    Button: ({ variant, disabled, onClick, children }) => (
      <button className={`btn btn-${variant}`} disabled={disabled} onClick={onClick} data-testid={`btn-${variant}`}>
        {children}
      </button>
    ),
  };
});

jest.mock('react-feather', () => ({
  AlertTriangle: () => <span data-testid="icon-alert" />,
  Check: ({ onClick }) => <span data-testid="icon-check" onClick={onClick} />,
  Clock: ({ onClick }) => <span data-testid="icon-clock" onClick={onClick} />,
  Trash: ({ onClick }) => <span data-testid="icon-trash" onClick={onClick} />,
}));

jest.mock('../ajax', () => ({
  create_line_comment: jest.fn().mockResolvedValue({ data: { id: 2, grade: {} } }),
  delete_line_comment: jest.fn().mockResolvedValue({ data: { grade: {} } }),
  autosave_line_comment: jest.fn().mockResolvedValue({ saved: true }),
}));

describe('LineComment', () => {
  const baseData = {
    id: 1,
    line: 10,
    path: 'test.c',
    points: '-5.0',
    text: 'Test comment',
    user: { name: 'Grader' },
    grade: {
      id: 1,
      confirmed: false,
    },
  };

  const newData = {
    id: null,
    uuid: 'uuid-123',
    line: 10,
    path: 'test.c',
    points: '',
    text: '',
    user: { name: 'Grader' },
    grade: {
      id: 1,
      confirmed: false,
    },
  };

  const mockActions = {
    setGrade: jest.fn(),
    updateThisComment: jest.fn(),
    removeThisComment: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('renders comment with correct data', () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    expect(screen.getByDisplayValue('-5.0')).toBeInTheDocument();
    expect(screen.getByDisplayValue('Test comment')).toBeInTheDocument();
    expect(screen.getByText('Grader: Grader')).toBeInTheDocument();
  });

  test('shows (new) for unsaved comments', () => {
    render(<LineComment data={newData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    expect(screen.getByText('id: (new)')).toBeInTheDocument();
  });

  test('disables inputs when grade is confirmed', () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={true} />);
    
    const pointsInput = screen.getByTestId('comment-points');
    const textArea = screen.getByTestId('comment-text');
    
    expect(pointsInput).toBeDisabled();
    expect(textArea).toBeDisabled();
  });

  test('enables inputs when grade is unconfirmed and edit is true', () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    const pointsInput = screen.getByTestId('comment-points');
    const textArea = screen.getByTestId('comment-text');
    
    expect(pointsInput).not.toBeDisabled();
    expect(textArea).not.toBeDisabled();
  });

  test('disables inputs when edit is false', () => {
    render(<LineComment data={baseData} edit={false} actions={mockActions} gradeConfirmed={false} />);
    
    const pointsInput = screen.getByTestId('comment-points');
    const textArea = screen.getByTestId('comment-text');
    
    expect(pointsInput).toBeDisabled();
    expect(textArea).toBeDisabled();
  });

  test('shows clock icon when comment is modified', () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    const textArea = screen.getByTestId('comment-text');
    fireEvent.change(textArea, { target: { value: 'Modified text' } });

    expect(screen.getByTestId('icon-clock')).toBeInTheDocument();
    expect(screen.getByTestId('btn-danger')).toBeInTheDocument();
  });

  test('hides clock icon and shows checkmark after save', async () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    const textArea = screen.getByTestId('comment-text');
    fireEvent.change(textArea, { target: { value: 'Modified text' } });

    expect(screen.getByTestId('icon-clock')).toBeInTheDocument();

    const clockIcon = screen.getByTestId('icon-clock');
    fireEvent.click(clockIcon);

    await waitFor(() => {
      expect(screen.getByTestId('icon-check')).toBeInTheDocument();
    });
    expect(screen.queryByTestId('icon-clock')).not.toBeInTheDocument();
    expect(screen.queryByText('...')).not.toBeInTheDocument();
  });

  test('shows ... during save, replaces clock icon', async () => {
    const slowSave = jest.fn().mockImplementation(() => 
      new Promise(resolve => setTimeout(() => resolve({ saved: true }), 100))
    );
    require('../ajax').autosave_line_comment = slowSave;
    
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    const textArea = screen.getByTestId('comment-text');
    fireEvent.change(textArea, { target: { value: 'Modified text' } });

    const clockIcon = screen.getByTestId('icon-clock');
    fireEvent.click(clockIcon);

    await waitFor(() => {
      expect(screen.getByText('...')).toBeInTheDocument();
    });
    expect(screen.queryByTestId('icon-clock')).not.toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByTestId('icon-check')).toBeInTheDocument();
    });
    expect(screen.queryByText('...')).not.toBeInTheDocument();
  });

  test('hides buttons when grade is confirmed', () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={true} />);
    
    expect(screen.queryByTestId('btn-danger')).not.toBeInTheDocument();
    expect(screen.queryByTestId('icon-clock')).not.toBeInTheDocument();
  });

  test('delete button calls delete_line_comment', async () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    const trashIcon = screen.getByTestId('icon-trash');
    fireEvent.click(trashIcon);

    await waitFor(() => {
      expect(require('../ajax').delete_line_comment).toHaveBeenCalledWith(1);
    });
    await waitFor(() => {
      expect(mockActions.removeThisComment).toHaveBeenCalled();
    });
  });

  test('delete button removes new comment without API call', () => {
    render(<LineComment data={newData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    const trashIcon = screen.getByTestId('icon-trash');
    fireEvent.click(trashIcon);

    expect(require('../ajax').delete_line_comment).not.toHaveBeenCalled();
    expect(mockActions.removeThisComment).toHaveBeenCalled();
  });

  test('clock button triggers immediate save', async () => {
    render(<LineComment data={baseData} edit={true} actions={mockActions} gradeConfirmed={false} />);
    
    const textArea = screen.getByTestId('comment-text');
    fireEvent.change(textArea, { target: { value: 'Modified text' } });

    const clockIcon = screen.getByTestId('icon-clock');
    fireEvent.click(clockIcon);

    await waitFor(() => {
      expect(require('../ajax').autosave_line_comment).toHaveBeenCalledWith(1, { points: '-5.0', text: 'Modified text' });
    });
  });
});