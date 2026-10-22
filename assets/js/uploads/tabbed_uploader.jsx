import React, { useEffect, useState } from 'react';
import { Tab, Tabs, Card, Form } from 'react-bootstrap';

import FileUploader from './file_uploader';
import GitUploader from './git_uploader';

// Mode flags arrive as `data-*` attributes: Phoenix renders an enabled flag as
// a bare attribute (so the dataset value is the empty string) and leaves a
// disabled one out entirely.
function enabled(flag) {
  return (typeof flag !== "undefined" && flag != "false");
}

export default function TabbedUploader({allowGit, allowFile, allowMarkdown, markdown, setUploadId, token, nonce}) {
  allowFile = enabled(allowFile);
  allowGit = enabled(allowGit);
  allowMarkdown = enabled(allowMarkdown);

  // If the server sent text back (the sub was rejected), start on the markdown
  // tab: that is where the student left off.
  const [tab, setTab] = useState(
    markdown ? "markdown" : (allowFile ? "file" : (allowGit ? "git" : "markdown"))
  );
  const [text, setText] = useState(markdown || "");

  let modes = [];
  if (allowFile) {
    modes.push("file");
  }
  if (allowGit) {
    modes.push("git");
  }
  if (allowMarkdown) {
    modes.push("markdown");
  }

  // Exactly one submission method may be posted. On submit, disable whichever
  // input is not in use; nothing is cleared, so switching tabs keeps both
  // values and the student can change their mind.
  useEffect(() => {
    const form = document.getElementById("new-sub-form");
    if (!form) {
      return;
    }

    function onSubmit() {
      const uploadId = document.getElementById("sub_upload_id");
      const editor = document.getElementById("sub_markdown");
      const useMarkdown = (tab === "markdown" && text.trim() !== "");

      if (editor) {
        editor.disabled = !useMarkdown;
      }
      if (uploadId) {
        uploadId.disabled = useMarkdown;
      }
    }

    form.addEventListener("submit", onSubmit);
    return () => form.removeEventListener("submit", onSubmit);
  }, [tab, text]);

  if (modes.length == 0) {
    return (
      <div>
        <p>No submission methods enabled.</p>
      </div>
    );
  }

  if (modes.length == 1) {
    return (
      <SingleMode mode={modes[0]} text={text} setText={setText}
                  setUploadId={setUploadId} token={token} nonce={nonce} />
    );
  }

  return (
    <Tabs activeKey={tab} onSelect={(k) => setTab(k)}>
      {allowFile && (
        <Tab eventKey="file" title="Upload File">
          <FileUploader setUploadId={setUploadId} token={token} />
        </Tab>
      )}
      {allowGit && (
        <Tab eventKey="git" title="Clone Git Repo">
          <GitUploader setUploadId={setUploadId} token={token} nonce={nonce} />
        </Tab>
      )}
      {allowMarkdown && (
        <Tab eventKey="markdown" title="Write Markdown">
          <MarkdownEditor text={text} setText={setText} />
        </Tab>
      )}
    </Tabs>
  );
}

function SingleMode({mode, text, setText, setUploadId, token, nonce}) {
  switch (mode) {
    case "file":
      return <FileUploader setUploadId={setUploadId} token={token} />;
    case "git":
      return <GitUploader setUploadId={setUploadId} token={token} nonce={nonce} />;
    case "markdown":
      return <MarkdownEditor text={text} setText={setText} />;
  }
}

function MarkdownEditor({text, setText}) {
  return (
    <Card>
      <Card.Body>
        <Form.Group controlId="sub_markdown">
          <Form.Label>Your submission (Markdown)</Form.Label>
          <Form.Control
            as="textarea"
            name="sub[markdown]"
            rows={16}
            value={text}
            onChange={(ev) => setText(ev.target.value)}
            placeholder="Type your submission here. Markdown is supported."
          />
        </Form.Group>
        <Form.Text className="text-muted">
          This is saved as submission.md, so your grader can comment on
          individual lines.
        </Form.Text>
      </Card.Body>
    </Card>
  );
}
