import React, { useState } from 'react';
import ReactDOM from 'react-dom/client';
import $ from 'cash-dom';

import { Row, Col, Form } from 'react-bootstrap';

const DEFAULTS = { cores: 1, megs: 1024, seconds: 300, allow_fuse: false };

export function Limits({target}) {
  let elem = document.getElementById(target);
  let state0 = DEFAULTS;

  try {
    let parsed = JSON.parse(elem.value);
    state0 = {
      cores: parsed.cores ?? DEFAULTS.cores,
      megs: parsed.megs ?? DEFAULTS.megs,
      seconds: parsed.seconds ?? DEFAULTS.seconds,
      allow_fuse: parsed.allow_fuse ?? DEFAULTS.allow_fuse,
    };
    elem.value = JSON.stringify(state0);
  }
  catch {
    elem.value = JSON.stringify(state0);  
  }
  const [state, setState] = useState(state0);

  function setNumber(name) {
    return function(ev) {
      let st1 = Object.assign({}, state);
      st1[name] = parseFloat(ev.target.value) || DEFAULTS[name];
      setState(st1);
      elem.value = JSON.stringify(st1);
    }
  }

  function setCheckbox(name) {
    return function(ev) {
      let st1 = Object.assign({}, state);
      st1[name] = ev.target.checked;
      setState(st1);
      elem.value = JSON.stringify(st1);
    }
  }

  return (
    <Row className="mx-4">
      <Col>
        <Form.Label>Cores</Form.Label>
        <Form.Control type="number" value={state.cores} onChange={setNumber('cores')} />
      </Col>
      <Col>
        <Form.Label>Megs</Form.Label>
        <Form.Control type="number" value={state.megs} onChange={setNumber('megs')} />
      </Col>
      <Col>
        <Form.Label>Seconds</Form.Label>
        <Form.Control type="number" value={state.seconds} onChange={setNumber('seconds')} />
      </Col>
      <Col>
        <Form.Label>Allow FUSE</Form.Label>
        <Form.Switch 
          checked={state.allow_fuse} 
          onChange={setCheckbox('allow_fuse')} 
        />
      </Col>
    </Row>
  );
}

function init() {
  let root_div = document.getElementById('gcol-limits-root');
  if (root_div) {
    let root = ReactDOM.createRoot(root_div);
    root.render(
      <Limits target="gcol-limits" />
    );
  }
}

$(init);