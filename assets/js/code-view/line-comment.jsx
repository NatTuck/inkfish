import React, { useState, useEffect, useRef } from 'react';
import { Card, Row, Col, Form, Button } from 'react-bootstrap';
import { AlertTriangle, Check, Clock, Trash } from 'react-feather';
import { debounce } from 'lodash';

import { create_line_comment, delete_line_comment,
         autosave_line_comment } from '../ajax';

export default function LineComment({data, edit, actions, gradeConfirmed}) {
  const [id, setId] = useState(data.id);
  const [points, setPoints] = useState(data.points);
  const [text, setText] = useState(data.text);
  const [status, setStatus] = useState(null);
  const [isModified, setIsModified] = useState(false);
  const lastSavedRef = useRef({ points: data.points, text: data.text });

  let {line, path} = data;

  const isLocked = gradeConfirmed === true;

  const doSave = (commentId, commentData, gradeId, path, line) => {
    if (isLocked) return;
    if (commentData.points === lastSavedRef.current.points && 
        commentData.text === lastSavedRef.current.text) return;

    setStatus("saving");

    if (commentId) {
      autosave_line_comment(commentId, commentData)
        .then((resp) => {
          if (resp.saved) {
            setStatus("saved");
            setIsModified(false);
            lastSavedRef.current = { points: commentData.points, text: commentData.text };
            window.setTimeout(() => setStatus(null), 2000);
          }
        })
        .catch((resp) => {
          console.log("autosave error", resp);
          if (resp.error === "grade_already_confirmed") {
            setStatus("error: grade confirmed");
          } else {
            setStatus("error");
          }
        });
    } else if (gradeId) {
      create_line_comment(gradeId, path, line, commentData.points, commentData.text)
        .then((resp) => {
          setId(resp.data.id);
          setStatus("saved");
          setIsModified(false);
          lastSavedRef.current = { points: commentData.points, text: commentData.text };
          actions.setGrade(resp.data.grade);
          actions.updateThisComment({...resp.data, uuid: data.uuid});
          window.setTimeout(() => setStatus(null), 2000);
        })
        .catch((resp) => {
          console.log("create error", resp);
          setStatus("error");
        });
    }
  };

  const debouncedSaveRef = useRef(debounce(doSave, 5000));

  const gradeId = data.grade_id || (data.grade && data.grade.id);

  useEffect(() => {
    if (!isLocked && text && (points !== lastSavedRef.current.points || text !== lastSavedRef.current.text)) {
      setIsModified(true);
      debouncedSaveRef.current(id, { points, text }, gradeId, path, line);
    }
  }, [points, text, id, isLocked]);

  let color = line_comment_color(points);

  function saveNow(ev) {
    ev.preventDefault();
    debouncedSaveRef.current.cancel();
    doSave(id, { points, text }, gradeId, path, line);
  }

  function delete_comment(ev) {
    ev.preventDefault();
    console.log("delete", data);

    debouncedSaveRef.current.cancel();

    if (id) {
      delete_line_comment(id)
        .then((resp) => {
          console.log("delete resp", resp);
          actions.removeThisComment();
          actions.setGrade(resp.data.grade);
        });
    }
    else {
      actions.removeThisComment();
    }
  }

  function Buttons({edit, locked, modified, saving}) {
    if (edit && !locked) {
      return (
        <span>
          {saving ? (
            <span className="px-2">...</span>
          ) : modified ? (
            <Button variant="secondary" onClick={saveNow}>
              <Clock />
            </Button>
          ) : null}
          <Button variant="danger">
            <Trash onClick={delete_comment} />
          </Button>
        </span>
      );
    }
    else {
      return (<span />);
    }
  }

  return (
    <Card className="comment-card" style={{maxWidth: "50vw"}}>
      <Card.Body className={color}>
        <Row>
          <Col sm={6}>
            <p>Grader: {data.user.name}</p>
          </Col>
          <Col sm={3}>
            <p>id: {id || "(new)"}</p>
          </Col>
          <Col sm={3} className="text-right">
            {status === "saved" ? <Check /> : null}
            {status && status.startsWith("error") ? <AlertTriangle /> : null}
            &nbsp;
            <Buttons edit={edit} locked={isLocked} modified={isModified} saving={status === "saving"} />
          </Col>
        </Row>
        <Row>
          <Col sm={2}>
            <Form.Control type="number"
                          value={points}
                          disabled={!edit || isLocked}
                          onChange={(ev) => {
                            setPoints(ev.target.value);
                          }} />
          </Col>
          <Col sm={10}>
            <Form.Control as="textarea"
                          rows="3"
                          value={text}
                          disabled={!edit || isLocked}
                          onChange={(ev) => {
                            setText(ev.target.value);
                          }} />
          </Col>
        </Row>
      </Card.Body>
    </Card>
  );
}

function line_comment_color(points) {
  let colors = "bg-secondary";
  if (points > 0) {
    colors = "bg-success text-white";
  }
  if (points < 0) {
    colors = "bg-warning";
  }
  return colors;
}
