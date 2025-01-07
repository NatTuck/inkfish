
import { elixir } from 'codemirror-lang-elixir';
import { cpp } from '@codemirror/lang-cpp';
import { java } from '@codemirror/lang-java';
import { python } from '@codemirror/lang-python';
import { javascript } from '@codemirror/lang-javascript';
import { html } from '@codemirror/lang-html';
import { css } from '@codemirror/lang-css';
import { xml } from '@codemirror/lang-xml';

import { StreamLanguage } from '@codemirror/language';
import { gas } from '@codemirror/legacy-modes/mode/gas';
import { perl } from '@codemirror/legacy-modes/mode/perl';

import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { languages } from '@codemirror/language-data';

function hasExt(path, exts) {
  return exts.some((ext) => path.endsWith('.' + ext));
}

export function detectLangModes(path, code) {
  if (hasExt(path, ['ex', 'exs'])) {
    return [elixir()];
  }

  if (hasExt(path, ['c', 'cpp', 'cc', 'cxx', 'h', 'hh', 'hxx', 'hpp'])) {
    return [cpp()];
  }

  if (hasExt(path, ['java'])) {
    return [java()];
  }

  if (hasExt(path, ['py'])) {
    return [python()];
  }

  if (hasExt(path, ['js', 'mjs', 'jsx'])) {
    return [javascript({jsx: true})];
  }

  if (hasExt(path, ['ts', 'mts', 'tsx'])) {
    return [javascript({jsx: true, typescript: true})];
  }

  if (hasExt(path, ['html'])) {
    return [html()];
  }

  if (hasExt(path, ['xml'])) {
    return [xml()];
  }

  if (hasExt(path, ['s', 'S'])) {
    return [StreamLanguage.define(gas)];
  }

  if (hasExt(path, ['pl'])) {
    return [StreamLanguage.define(perl)];
  }

  if (hasExt(path, ['md'])) {
    return [markdown(
      {base: markdownLanguage, codeLanguages: languages}
    )];
  }

  return [];
}
