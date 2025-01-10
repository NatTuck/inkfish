import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Card, Row, Col, Form, Button } from 'react-bootstrap';
import { AlertTriangle, Check, Save, Trash } from 'react-feather';

import { create_line_comment, delete_line_comment,
         update_line_comment} from '../ajax';

export default function LineComment({data, edit, actions}) {
  const [id, setId] = useState(data.id);
  const [points, setPoints] = useState(data.points);
  const [text, setText] = useState(data.text);
  const [status, setStatus] = useState(null);

  let {line, path} = data;

  let color = line_comment_color(points);
  let icons = [];

  if (status) {
    if (status == "ok") {
      // TODO: Make this actually display.
      icons.push(<Check key="ok" />);
    }
    else {
      // TODO: Show error message.
      icons.push(<AlertTriangle key="err" />);
    }
  }

  function clearStatus() {
    window.setTimeout(() => setStatus(null), 5);
  }

  function handle_enter(ev) {
    if (ev.which == 13) {
      ev.preventDefault();
      save(ev);
    }
  }

  function save_comment(ev) {
    ev.preventDefault();
    if (id) {
      update_line_comment(id, points, text)
        .then((resp) => {
          console.log("update resp", resp);
          setStatus("ok");
          actions.setGrade(resp.data.grade);
          actions.updateThisComment(resp.data);
        })
        .catch((resp) => {
          console.log("error saving", resp);
          let msg = JSON.stringify(resp);
          setStatus(msg);
        });
    }
    else {
      console.log("aa");
      // First save
      create_line_comment(data.grade.id, path, line, points, text)
        .then((resp) => {
          console.log("create resp", resp);
          setId(resp.data.id);
          setStatus("ok");
          actions.setGrade(resp.data.grade);
          actions.updateThisComment({...resp.data, uuid: data.uuid});
        })
        .catch((resp) => {
          console.log("error creating", resp);
          let msg = JSON.stringify(resp);
          setStatus(msg);
        });
    }
  }

  function delete_comment(ev) {
    ev.preventDefault();
    if (data.id) {
      delete_line_comment(data.id)
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

  function Buttons({edit}) {
    if (edit) {
      return (
        <span>
          <Button variant="success"
                  disabled={points == data.points && text == data.text}>
            <Save onClick={save_comment} />
          </Button>
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
    <Card className="comment-card">
      <Card.Body className={color}>
        <Row>
          <Col sm={6}>
            <p>Grader: {data.user.name}</p>
          </Col>
          <Col sm={3}>
            <p>id: {id || "(unsaved)"}</p>
          </Col>
          <Col sm={3} className="text-right">
            { icons }
            &nbsp;
            <Buttons edit={edit} />
          </Col>
        </Row>
        <Row>
          <Col sm={2}>
            <Form.Control type="number"
                          onKeyPress={handle_enter}
                          value={points}
                          disabled={!edit}
                          onChange={(ev) => {
                            setPoints(ev.target.value);
                            clearStatus();
                          }} />
          </Col>
          <Col sm={10}>
            <Form.Control as="textarea"
                          rows="3"
                          value={text}
                          disabled={!edit}
                          onChange={(ev) => {
                            setText(ev.target.value);
                            clearStatus();
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
