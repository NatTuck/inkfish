import { useEffect, useState } from 'react';
import { Tab, Tabs, Card, Form } from 'react-bootstrap';

import FileUploader from './file_uploader';
import GitUploader from './git_uploader';

// Mode flags arrive as `data-*` attributes: Phoenix renders an enabled flag as
// a bare attribute (so the dataset value is the empty string) and leaves a
// disabled one out entirely.
function enabled(flag) {
  return (typeof flag !== "undefined" && flag != "false");
}

export default function TabbedUploader({allowGit, allowFile, allowMarkdown, markdown, uploadField, markdownField, setUploadId, token, nonce}) {
  allowFile = enabled(allowFile);
  allowGit = enabled(allowGit);
  allowMarkdown = enabled(allowMarkdown);

  // The template says which ids it rendered, so the JS and the form cannot
  // drift apart.
  const uploadFieldId = uploadField || "sub_upload_id";
  const markdownFieldId = markdownField || "sub_markdown";

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
    const uploadId = document.getElementById(uploadFieldId);
    const editor = document.getElementById(markdownFieldId);

    // The form is found through its own fields rather than by id: putting an
    // `id` on `<.form>` would also rename every field id (including
    // `sub_upload_id`, which `data-upload-field` points at).
    const form = (uploadId && uploadId.form) || (editor && editor.form);
    if (!form) {
      return;
    }

    function onSubmit(ev) {
      const hasText = text.trim() !== "";
      const hasUpload = uploadId ? uploadId.value !== "" : false;

      // A typed answer with no file attached is the only thing there is to
      // submit, whichever tab is showing; failing with "Upload id is invalid"
      // would lose it.
      let useMarkdown = hasText && (tab === "markdown" || !hasUpload);

      // Both are ready and a file tab is showing. Submit means the file here,
      // but dropping a typed answer without asking would be silent.
      if (hasText && hasUpload && tab !== "markdown") {
        if (!window.confirm("Submit the attached file and discard your typed answer?")) {
          ev.preventDefault();
          setTab("markdown");
          return;
        }
        useMarkdown = false;
      }

      if (editor) {
        editor.disabled = !useMarkdown;
      }
      if (uploadId) {
        uploadId.disabled = useMarkdown;
      }
    }

    form.addEventListener("submit", onSubmit);
    return () => form.removeEventListener("submit", onSubmit);
  }, [tab, text, uploadFieldId, markdownFieldId]);

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
                  fieldId={markdownFieldId} setUploadId={setUploadId}
                  token={token} nonce={nonce} />
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
          <MarkdownEditor text={text} setText={setText} fieldId={markdownFieldId} />
        </Tab>
      )}
    </Tabs>
  );
}

function SingleMode({mode, text, setText, fieldId, setUploadId, token, nonce}) {
  switch (mode) {
    case "file":
      return <FileUploader setUploadId={setUploadId} token={token} />;
    case "git":
      return <GitUploader setUploadId={setUploadId} token={token} nonce={nonce} />;
    case "markdown":
      return <MarkdownEditor text={text} setText={setText} fieldId={fieldId} />;
  }
}

function MarkdownEditor({text, setText, fieldId}) {
  return (
    <Card>
      <Card.Body>
        <Form.Group controlId={fieldId}>
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
