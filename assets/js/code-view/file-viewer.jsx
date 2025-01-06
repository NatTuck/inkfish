import React, { useEffect, useRef, useMemo } from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import { Card } from 'react-bootstrap';
import _ from 'lodash';

import CodeMirror from '@uiw/react-codemirror';

import LineComment from './line-comment';
import { detectMode } from './langs';

import { create_line_comment } from '../ajax';

export default function FileViewer({path, data, grade, setGrade}) {
  const texts = useMemo(() => build_texts_map(data.files), [data.files]);
  const text = texts.get(path);
  
  let extensions = [];
  let langMode = detectMode(path, text);
  if (langMode) {
    extensions.push(langMode);
  }

  return (
    <CodeMirror value={text}
                extensions={extensions}
                readOnly={true}
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

