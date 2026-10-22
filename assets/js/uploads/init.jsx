import React from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import $ from 'cash-dom';

import FileUploader from './file_uploader';
import TabbedUploader from './tabbed_uploader';
import * as history from '../console/history';

function render_uploader(Uploader, item) {
  let data = item.dataset;
  let field = data.uploadField;

  function gotUUID(uuid) {
    let input = document.getElementById(field);
    if (!input) {
      // A missing field used to throw inside the upload promise, which left
      // the upload looking finished while the id was never set. Say what is
      // wrong instead.
      console.error("upload field is missing from the page:", field);
      return;
    }
    input.value = uuid;
  }

  if (data.nonce) {
    const topic = "clone:" + data.nonce;
    history.join(topic, data.token, () => {});
  }

  var root = createRoot(item);
  root.render(
    <Uploader setUploadId={gotUUID} {...data} />
  );
}

function init() {
  $('.file-uploader').each((_ii, item) => {
    render_uploader(FileUploader, item);
  });

  $('.tabbed-uploader').each((_ii, item) => {
    render_uploader(TabbedUploader, item);
  });
}

$(init);
