import React from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import $ from 'cash-dom';

import Viewer from './viewer';

function init() {
  $('.code-viewer').each((_ii, item) => {
    const root = createRoot(item);
    root.render(<Viewer data={window.code_view_data} />);
  });
}

$(init);

