import React from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import { freeze } from 'icepick';
import _ from 'lodash';

export function TeamSuggestions({data, active}) {
  let students = [];
  for (let reg of data.course.regs) {
    if (reg.is_student) {
      students.push(reg.user);
    }
  }

  return (
    <div>
      <pre>{JSON.stringify(active, null, 2)}</pre><br/>
      <pre>{JSON.stringify(students, null, 2)}</pre><br/>
      <pre>{JSON.stringify(data.past, null, 2)}</pre>
    </div>
  );
}

