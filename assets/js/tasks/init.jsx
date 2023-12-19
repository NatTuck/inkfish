import React from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import $ from 'cash-dom';

import TaskEditor from './task-editor';

function init() {
  $('#grading-task-editor').each((_ii, item) => {
    let graders = window.grading_task_graders;
    let asg = window.grading_task_asg;
    let root = createRoot(item);
    root.render(
      <TaskEditor graders={graders} assignment={asg} />
    );
  });
}

$(init);
