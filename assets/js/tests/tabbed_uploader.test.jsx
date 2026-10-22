import '@testing-library/jest-dom';
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';

import TabbedUploader from '../uploads/tabbed_uploader';

// The real git uploader pulls in the Phoenix socket stack (and an ESM-only
// dependency jest does not transform). It is not what this file tests.
jest.mock('../uploads/git_uploader', () => {
  const React = require('react');
  return function MockGitUploader() {
    return React.createElement('div', null, 'git uploader');
  };
});

function make_form() {
  const form = document.createElement('form');
  form.id = 'new-sub-form';

  const upload_id = document.createElement('input');
  upload_id.id = 'sub_upload_id';
  upload_id.name = 'sub[upload_id]';
  form.appendChild(upload_id);

  document.body.appendChild(form);
  return form;
}

function editor() {
  return document.getElementById('sub_markdown');
}

function upload_id_input() {
  return document.getElementById('sub_upload_id');
}

describe('TabbedUploader', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  test('renders the markdown editor when it is the only mode', () => {
    render(
      <TabbedUploader allowMarkdown="" setUploadId={() => {}} token="tok" />
    );

    expect(screen.getByText('Your submission (Markdown)')).toBeInTheDocument();
    expect(editor()).not.toBeNull();
    expect(screen.queryByText('Upload File')).not.toBeInTheDocument();
  });

  test('renders tabs when several modes are allowed', () => {
    render(
      <TabbedUploader
        allowMarkdown=""
        allowFile=""
        setUploadId={() => {}}
        token="tok"
      />
    );

    expect(screen.getByText('Upload File')).toBeInTheDocument();
    expect(screen.getByText('Write Markdown')).toBeInTheDocument();
  });

  test('says so when no mode is allowed', () => {
    render(<TabbedUploader setUploadId={() => {}} token="tok" />);

    expect(screen.getByText('No submission methods enabled.')).toBeInTheDocument();
  });

  test('starts the editor with the text the server kept', () => {
    render(
      <TabbedUploader
        allowMarkdown=""
        markdown="# Kept"
        setUploadId={() => {}}
        token="tok"
      />
    );

    expect(editor().value).toBe('# Kept');
  });

  test('starts on the markdown tab when the server kept text', () => {
    const form = make_form();

    render(
      <TabbedUploader
        allowMarkdown=""
        allowFile=""
        markdown="# Kept"
        setUploadId={() => {}}
        token="tok"
      />
    );

    fireEvent.submit(form);

    expect(editor().disabled).toBe(false);
    expect(upload_id_input().disabled).toBe(true);
  });

  test('typing updates the textarea that gets submitted', () => {
    render(
      <TabbedUploader allowMarkdown="" setUploadId={() => {}} token="tok" />
    );

    fireEvent.change(editor(), { target: { value: '# Hello' } });

    expect(editor().value).toBe('# Hello');
    expect(editor().name).toBe('sub[markdown]');
  });

  test('submits only the markdown when it is being used', () => {
    const form = make_form();

    render(
      <TabbedUploader allowMarkdown="" setUploadId={() => {}} token="tok" />
    );

    fireEvent.change(editor(), { target: { value: '# Hello' } });
    fireEvent.submit(form);

    expect(editor().disabled).toBe(false);
    expect(upload_id_input().disabled).toBe(true);
  });

  test('submits nothing from a blank editor', () => {
    const form = make_form();

    render(
      <TabbedUploader allowMarkdown="" setUploadId={() => {}} token="tok" />
    );

    fireEvent.submit(form);

    expect(editor().disabled).toBe(true);
    expect(upload_id_input().disabled).toBe(false);
  });

  test('submits only the upload when the file tab is active', () => {
    const form = make_form();

    render(
      <TabbedUploader
        allowMarkdown=""
        allowFile=""
        setUploadId={() => {}}
        token="tok"
      />
    );

    fireEvent.change(editor(), { target: { value: 'typed but not attached' } });
    fireEvent.submit(form);

    expect(editor().disabled).toBe(true);
    expect(upload_id_input().disabled).toBe(false);
  });

  test('switching to the markdown tab submits the text', () => {
    const form = make_form();

    render(
      <TabbedUploader
        allowMarkdown=""
        allowFile=""
        setUploadId={() => {}}
        token="tok"
      />
    );

    fireEvent.click(screen.getByText('Write Markdown'));
    fireEvent.change(editor(), { target: { value: '# Hello' } });
    fireEvent.submit(form);

    expect(editor().disabled).toBe(false);
    expect(upload_id_input().disabled).toBe(true);
  });
});
