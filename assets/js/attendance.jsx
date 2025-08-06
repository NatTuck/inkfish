import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import { Button, Form, InputGroup } from 'react-bootstrap';
import $ from 'cash-dom';

import socket from './socket';

let channel = null;

function connect(course_id, setState) {
  let token = window.user_token;
  channel = socket.channel("attendance:" + course_id, {token});
  channel.join()
    .receive("ok", setState)
    .receive("error", (msg) => {
      console.log("error joining attendence", msg);
    });
  channel.on("state", setState);
}

function disconnect() {
  if (channel) {
    channel.leave();
    channel = null;
  }
}

function AttBox({course_id, children}) {
  return (
    <div className="border border-secondary m-2 p-2">
      <p>
        <strong>Attendance</strong>
        &nbsp;
        (<a href={"/courses/" + course_id + "/meetings"}>Meetings</a>)
      </p>
      { children }
    </div>
  );
}

function AttForm({state, setState}) {
  const [code, setCode] = useState("");
  const [disabled, setDisabled] = useState(false);
  const [msg, setMsg] = useState(null);

  function setErrorMessage(mm) {
    setCode("");
    setDisabled(false);
    setMsg(mm);
  }

  function changeCode(ev) {
    setCode(ev.target.value);
  }

  function sendCode(ev) {
    ev.preventDefault();

    if (disabled) {
      console.log("Already sending...");
      return;
    }
    
    setDisabled(true);

    console.log(code);
    channel
      .push("code", {code: code})
      .receive("ok", setState)
      .receive("error", setErrorMessage);
  }

  return (
    <Form onSubmit={sendCode}>
      <InputGroup className="mb-3 row">
        <Form.Label htmlFor="code-input" className="mx-2 mt-1 col-1">
          Enter&nbsp;code:
        </Form.Label>
        <div className="col-3">
          <Form.Control id="code-input" type="text" 
            disabled={disabled} value={code} onChange={changeCode} />
        </div>
        <Button variant="primary" className="mx-2 col-1" 
          disabled={disabled} onClick={sendCode}>
          I'm&nbsp;Here!
        </Button>
        <div className="mx-2 col-2 form-text">
          { msg } 
        </div>
      </InputGroup>
    </Form>
  );
}

function AttendanceWidget({course_id}) {
  const [state, setState] = useState({mode: 'connecting'});

  useEffect(() => {
    connect(course_id, setState);
    return disconnect;
  }, [course_id]);

  if (state.mode == "connecting") {
    return (
      <AttBox course_id={course_id}>
        <p>Connecting...</p>
      </AttBox>
    );
  }

  if (!state.meeting) {
    return (
      <AttBox course_id={course_id}>
        <p>No current meeting.</p>
      </AttBox>
    );
  }

  if (state.attendance) {
    return (
      <AttBox course_id={course_id}>
        <p>{state.meeting.started_at}: Present; {state.attendance.status}</p>
      </AttBox>
    );
  }

  return (
    <AttBox course_id={course_id}>
      <AttForm state={state} setState={setState} />
    </AttBox>
  );
}

export function init() {
  let root_div = document.getElementById('attendance-widget');
  if (root_div) {
    let {courseId} = root_div.dataset;
  
    let root = ReactDOM.createRoot(root_div);
    root.render(
      <AttendanceWidget course_id={courseId} />
    ); 
  }
}

$(init);
