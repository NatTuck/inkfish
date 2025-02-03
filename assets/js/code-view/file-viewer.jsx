import React, { useEffect, useRef, useMemo, useState } from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import { Card, Button } from 'react-bootstrap';
import _ from 'lodash';

import CodeMirror from '@uiw/react-codemirror';
import { lineNumbers, highlightSpecialChars, scrollPastEnd } from '@codemirror/view';
import { foldGutter, syntaxHighlighting, defaultHighlightStyle } from '@codemirror/language';

import LineComment from './line-comment';
import { detectLangModes } from './langs';

import { make_lc, same_lc, lcs_del, lcs_put } from './lc-utils';
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
  constructor(lc, edit, actions) {
    super();
    this.lc = lc;
    this.edit = edit;
    this.actions = actions;
  }

  eq(that) {
    return same_lc(this.lc, that.lc);
  }

  toDOM(view) {
    let this_lc = this.lc;

    function removeThisComment() {
      let lcs = view.state.field(lcState);
      lcs = lcs_del(lcs, this_lc);
      view.dispatch({effects: [lcSetState.of(lcs)]});
      
      actions.delComment(this_lc);
    }

    function updateThisComment(updated_lc) {
      let lcs = view.state.field(lcState);
      lcs = lcs_del(lcs, this_lc);
      lcs = lcs_put(lcs, updated_lc);
      view.dispatch({effects: [lcSetState.of(lcs)]});

      actions.delComment(this_lc);
      actions.putComment(updated_lc);
    }

    let actions = {...this.actions, removeThisComment, updateThisComment};

    let lc_div = document.createElement("div");
    let lc_root = createRoot(lc_div);
    lc_root.render(
      <LineComment
        data={this.lc}
        edit={this.edit}
        actions={actions}
      />
    );
    return lc_div;
  }
}

function QuickSave({data, actions}) {
  function saveGrade(ev) {
    ev.preventDefault();

    let path = "Ω_grading_extra.txt";
    create_line_comment(data.grade.id, path, 1, 0, "okay")
      .then((resp) => {
        console.log("create resp", resp);
        actions.setGrade(resp.data.grade);
        window.location.reload();
      })
      .catch((resp) => {
        console.log("error creating", resp);
        let msg = JSON.stringify(resp);
        setStatus(msg);
      });
  }
  
  return (
    <p>
      <Button variant="info"
              onClick={saveGrade}>Full Credit</Button>
    </p>
  );
}

export default function FileViewer({path, data, grade, setGrade}) {
  const texts = useMemo(() => build_texts_map(data.files), [data.files]);
  const text = texts.get(path) || "(missing)";

  const [comments, setComments] = useState(data.grade.line_comments);

  let pathComments = comments.filter((lc) => lc.path == path);
  data = {...data, text, path, grade, comments: pathComments};

  function putComment(lc) {
    setComments(lcs_put(comments, lc));
  }

  function delComment(lc) {
    setComments(lcs_del(comments, lc));
  }
  
  let actions = { setGrade, putComment, delComment };

  let qs = null;
  if (grade.score == null) {
    qs = <QuickSave data={data} actions={actions} />;
  }
  
  console.log(grade);

  return (
    <div>
      { qs }
      <OneFile key={path} data={data} actions={actions} />
    </div>
  );
}

function OneFile({data, actions}) {
  if (data.path == "") {
    return <NoFile />;
  }

  function gutter_click(view, info, ev) {
    ev.preventDefault();

    let line = view.state.doc.lineAt(info.from).number;
    let new_lc = make_lc(line, data.path, data.grade, data.grader);

    let lcs = view.state.field(lcState);
    lcs = lcs_put(lcs, new_lc);
    view.dispatch({effects: [lcSetState.of(lcs)]});

    actions.putComment(new_lc);
  }

  function makeLcWidgets(state) {
    let lcs = state.field(lcState);

    let ranges = lcs.map((lc) => {
      let lcw = new LineCommentWidget(lc, data.edit, actions);
      let lv = Decoration.widget({widget: lcw, block: true});
      let line = state.doc.line(lc.line);
      return lv.range(line.from);
    });

    return RangeSet.of(ranges, true);
  }
  
  let extensions = detectLangModes(data.path, data.text);

  if (data.edit) {
    extensions.push(lineNumbers({domEventHandlers: { click: gutter_click } }));
  }
  else {
    extensions.push(lineNumbers());
  }

  extensions.push(
    highlightSpecialChars(),
    scrollPastEnd(),
    //foldGutter(),
    syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
    EditorState.readOnly.of(true),
    lcState.init((_) => data.comments),
    EditorView.decorations.compute(["doc", lcState], makeLcWidgets),
  );

  return (
    <div className="border">
      <CodeMirror basicSetup={false}
                  value={data.text}
                  extensions={extensions}
      />
    </div>
  );
} 

function NoFile() {
  return (
    <Card>
      <Card.Body>
        <p>Select a file from the list to the left.</p>
        <p>Click items starting with "+" to expand a directory.</p>
      </Card.Body>
    </Card>
  );
}

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

