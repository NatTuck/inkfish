import React from 'react';

export default function CodeMirror({ value, extensions }) {
  return (
    <div className="codemirror-mock" data-testid="codemirror">
      <pre>{value}</pre>
    </div>
  );
}

export const lineNumbers = () => [];
export const highlightSpecialChars = () => [];
export const scrollPastEnd = () => [];
export const EditorView = {
  lineWrapping: {},
};
export const Decoration = {
  widget: () => {},
};
export const WidgetType = class WidgetType {
  constructor() {}
  toDOM() {
    return document.createElement('div');
  }
};
export const StateField = {
  define: () => [],
};
export const StateEffect = {
  define: () => {},
};
export const RangeSet = {
  of: () => [],
};
export const StreamLanguage = {
  define: () => [],
};
export const syntaxHighlighting = () => [];
export const defaultHighlightStyle = {};
export const EditorState = {
  readOnly: {
    of: () => [],
  },
};