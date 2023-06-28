import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Card, Button, Alert, Row, Col, Form } from 'react-bootstrap';
import { Provider } from 'react-redux';
import classnames from 'classnames';

import { Itty, withChannel } from '../itty';
import store from '../itty/store';
import UploadInfo from './upload_info';

export default function GitUploader({setUploadId, token, nonce}) {
  const [url, setUrl] = useState("");
  const [upload, setUpload] = useState(null);
  const [started, setStarted] = useState(false);

  function startClone() {
    withChannel((channel) => {
      channel.push("clone", {url});

      channel.on("done", (msg) => {
	console.log("upload_ready", msg);
	if (msg.upload) {
	  setUpload(msg.upload);
	  setUploadId(msg.upload.id);
	}
      });
    });

    setStarted(true);
  }

  if (upload) {
    return (
      <UploadInfo upload={upload} clear={() => setUpload("")} />
    );
  }
 
  function handle_enter(ev) {
    if (ev.which == 13) {
      ev.preventDefault();
      startClone();
    }
  }

  return (
    <Provider store={store}>
      <Card>
	<Card.Body>
	  <Row>
	    <Col sm={2}>
	      <Form.Label htmlFor="git-repo-url" className="col-form-label">
		Repo&nbsp;URL:
	      </Form.Label>
	    </Col>
	    <Col sm={8} className="form-group">
	      <Form.Control type="text" value={url}
			    onChange={(ev) => setUrl(ev.target.value)}
			    onKeyPress={handle_enter}
			    id="git-repo-url"
			    placeholder="https://github.com/YourName/repo.git" />
	    </Col>
	    <Col sm={2}>
	      <Button color="secondary"
		      disabled={started}
		      onClick={startClone}>
		Clone Repo
	      </Button>
	    </Col>
	  </Row>
	  <Row>
	    <Itty chan="clone" uuid={nonce} token={token} />
	  </Row>
	</Card.Body>
      </Card>
    </Provider>
  );
}

