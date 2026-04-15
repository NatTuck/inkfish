import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';

import { Limits } from '../gcol/limits';

describe('Limits component', () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <input id="gcol-limits" value="" />
      <div id="gcol-limits-root"></div>
    `;
  });

  test('renders all four fields', () => {
    render(<Limits target="gcol-limits" />);
    expect(screen.getByText('Cores')).toBeInTheDocument();
    expect(screen.getByText('Megs')).toBeInTheDocument();
    expect(screen.getByText('Seconds')).toBeInTheDocument();
    expect(screen.getByText('Allow FUSE')).toBeInTheDocument();
  });

  test('uses default values when input empty', () => {
    render(<Limits target="gcol-limits" />);
    const input = document.getElementById('gcol-limits');
    expect(JSON.parse(input.value)).toEqual({
      cores: 1,
      megs: 1024,
      seconds: 300,
      allow_fuse: false,
    });
  });

  test('parses existing JSON from input', () => {
    document.getElementById('gcol-limits').value =
      '{"cores":2,"megs":2048,"seconds":600,"allow_fuse":true}';
    render(<Limits target="gcol-limits" />);

    const coresInput = screen.getByDisplayValue('2');
    const megsInput = screen.getByDisplayValue('2048');
    const secondsInput = screen.getByDisplayValue('600');
    const checkbox = screen.getByRole('checkbox');

    expect(coresInput).toBeInTheDocument();
    expect(megsInput).toBeInTheDocument();
    expect(secondsInput).toBeInTheDocument();
    expect(checkbox).toBeChecked();
  });

  test('checkbox toggles allow_fuse', () => {
    render(<Limits target="gcol-limits" />);
    const checkbox = screen.getByRole('checkbox');

    expect(checkbox).not.toBeChecked();
    fireEvent.click(checkbox);

    const input = document.getElementById('gcol-limits');
    expect(JSON.parse(input.value).allow_fuse).toBe(true);
  });

  test('handles missing fields with defaults', () => {
    document.getElementById('gcol-limits').value = '{"cores":2}';
    render(<Limits target="gcol-limits" />);
    const input = document.getElementById('gcol-limits');
    expect(JSON.parse(input.value)).toEqual({
      cores: 2,
      megs: 1024,
      seconds: 300,
      allow_fuse: false,
    });
  });

  test('number inputs update JSON correctly', () => {
    render(<Limits target="gcol-limits" />);

    const numberInputs = screen.getAllByRole('spinbutton');
    const coresInput = numberInputs[0];
    fireEvent.change(coresInput, { target: { value: '4' } });

    const input = document.getElementById('gcol-limits');
    expect(JSON.parse(input.value).cores).toBe(4);
  });
});