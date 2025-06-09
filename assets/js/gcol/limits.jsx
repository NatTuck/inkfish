import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import $ from 'cash-dom';

import { Row, Col, Form } from 'react-bootstrap';

function Limits({target}) {
  let state0 = {cores: 1, megs: 1024, seconds: 300};
  let elem = document.getElementById(target);
  try {
    state0 = JSON.parse(elem.value);
  }
  catch {
    elem.value = JSON.stringify(state0);  
  }
  const [state, setState] = useState(state0);

  function set(name) {
    return function(ev) {
      let st1 = Object.assign({}, state);
      st1[name] = ev.target.value;
      setState(st1);

      let st2 = {};
      for (let kk of Object.keys(st1)) {
        st2[kk] = parseFloat(st1[kk]); 
      }

      let elem = document.getElementById(target);
      elem.value = JSON.stringify(st2);
    }
  }

  return (
    <Row className="mx-4">
      <Col>
        Cores 
        <Form.Control value={state.cores} onChange={set('cores')} />
      </Col>
      <Col>
        Megs 
        <Form.Control value={state.megs} onChange={set('megs')} />
      </Col>
      <Col>
        Seconds 
        <Form.Control value={state.seconds} onChange={set('seconds')} />
      </Col>
    </Row>
  );
}

function init() {
  let root_div = document.getElementById('gcol-limits-root');
  let root = ReactDOM.createRoot(root_div);
  root.render(
    <Limits target="gcol-limits" />
  );
}

$(init);
