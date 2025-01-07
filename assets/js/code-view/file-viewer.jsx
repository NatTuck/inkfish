import React, { useEffect, useRef, useMemo } from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import { Card } from 'react-bootstrap';
import _ from 'lodash';

import CodeMirror from '@uiw/react-codemirror';
import { lineNumbers, highlightSpecialChars, scrollPastEnd } from '@codemirror/view';
import { foldGutter, syntaxHighlighting, defaultHighlightStyle } from '@codemirror/language';

import LineComment from './line-comment';
import { detectLangModes } from './langs';

import { create_line_comment } from '../ajax';

import { EditorView, WidgetType, Decoration,
         ViewUpdate, ViewPlugin } from '@codemirror/view';
import { EditorState, Range, RangeSet,
         StateField, StateEffect } from '@codemirror/state';

const lcSetState = StateEffect.define({});

const lcState = StateField.define({
  create(state) {
    return [];
  },
  update(lcs0, tx) {
    for (let eff of tx.effects) {
      if (eff.is(lcSetState)) {
        return eff.value;
      }
    }
    return lcs0;
  }
});

class LineCommentWidget extends WidgetType {
  constructor(lc) {
    super();
    this.lc = lc;
  }

  toDOM() {
    console.log("Rendering widget");
    
    let lc_div = document.createElement("div");
    let lc_root = createRoot(lc_div);
    lc_root.render(
      <div>This is a react component.</div>
    );
    return lc_div;
  }
}

class LcPlug {
  constructor() {
    this.decos = RangeSet.empty;
  }

  update(change) {
    console.log("change", change);
    
    let lcs = change.state.field(lcState);
    let ranges = lcs.map((lc) => {
      let lcw = new LineCommentWidget(lc);
      let lv = Decoration.widget({widget: lcw, block: true});
      let line = change.state.doc.line(lc.line);
      return lv.range(line.from);
    });

    console.log("Ranges", ranges);

    this.decos = RangeSet.of(ranges, true);
  }
}

const lcSpec = {
  decorations: vp => vp.decos,
};

const lineCommentsPlugin = ViewPlugin.fromClass(LcPlug, lcSpec);

function makeLcWidgets(state) {
  let lcs = state.field(lcState);

  let ranges = lcs.map((lc) => {
    let lcw = new LineCommentWidget(lc);
    let lv = Decoration.widget({widget: lcw, block: true});
    let line = state.doc.line(lc.line);
    return lv.range(line.from);
  });

  console.log("Ranges", ranges);

  return RangeSet.of(ranges, true);
}

export default function FileViewer({path, data, grade, setGrade}) {
  const texts = useMemo(() => build_texts_map(data.files), [data.files]);
  const text = texts.get(path);

  function gutter_click(view, info, ev) {
    ev.preventDefault();

    let line = view.state.doc.lineAt(info.from).number;
    let lcs0 = view.state.field(lcState);
    let lcs1 = lcs0.concat([{line}]);

    view.dispatch({
      effects: lcSetState.of(lcs1),
    });
  }
  
  let extensions = detectLangModes(path, text);
  extensions.push(
    lineNumbers({domEventHandlers: { click: gutter_click } }),
    highlightSpecialChars(),
    scrollPastEnd(),
    foldGutter(),
    syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
    EditorState.readOnly.of(true),
    lcState.extension,
    EditorView.decorations.compute(["doc", lcState], makeLcWidgets),
  );

  return (
    <CodeMirror basicSetup={false}
                value={text}
                extensions={extensions}
    />
  );
} 

/*
  export default function FileViewer({path, data, grade, setGrade}) {
  const texts = useMemo(() => build_texts_map(data.files), [data.files]);
  const editor = useRef(null);

  //console.log("grade", grade);

  function gutter_click(_cm, line, _class, ev) {
  ev.preventDefault();
  _.debounce(() => {
  console.log(line, ev);
  create_line_comment(grade.id, path, line)
  .then((resp) => {
  console.log("resp", resp);
  setGrade(resp.data.grade);
  });
  }, 100, {leading: true})();
  }

  useEffect(() => {
  let cm = CodeMirror(editor.current, {
  readOnly: true,
  lineNumbers: true,
  lineWrapping: true,
  value: texts.get(path) || "(missing)",
  });

  if (data.edit) {
  cm.on("gutterClick", gutter_click);
  }

  for (let lc of grade.line_comments) {
  if (lc.path != path) {
  continue;
  }

      if (!cm.lineInfo(lc.line)) {
        lc.line = 0;
      }

      //let info = cm.lineInfo(lc.line);
      //console.log(lc, info);

      let lc_div = document.createElement("div");
      lc_div.setAttribute('id', `line-comment-${lc.id}`);
      let lc_root = createRoot(lc_div);
      let node = cm.addLineWidget(lc.line, lc_div, {above: true});
      lc_root.render(
        <LineComment data={lc} setGrade={setGrade}
                     edit={data.edit} node={node} />
      );
    }

    //console.log("insert codemirror");

    return () => {
      cm.getWrapperElement().remove();
      //console.log("remove codemirror");
    };
  });

  if (path == "") {
    return (
      <Card>
        <Card.Body>
          <p>Select a file from the list to the left.</p>
          <p>Click items starting with "+" to expand a directory.</p>
        </Card.Body>
      </Card>
    );
  }

  return (
    <Card className="vh-100">
      <Card.Body className="vh-100">
        <Card.Title>{path}</Card.Title>
        <div ref={editor} />
      </Card.Body>
    </Card>
  );
}
*/

function build_texts_map(node) {
  let mm = new Map();

  if (node.text) {
    mm.set(node.path, node.text);
  }

  if (node.nodes) {
    for (let kid of node.nodes) {
      let kidmap = build_texts_map(kid);
      for (let [kk, vv] of kidmap) {
        mm.set(kk, vv);
      }
    }
  }

  return mm;
}

