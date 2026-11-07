import React from 'react';
import { createRoot } from 'react-dom/client';
import $ from 'cash-dom';

import LineComment from './line-comment';

function initConfirmReview() {
  const comments = window.confirm_review_comments || [];
  const gradeConfirmed = window.confirm_review_grade_confirmed;

  const actions = {
    // Confirm-review mode shows the comments but does not edit them; these are
    // the callbacks `LineComment` expects to be able to call, and the grade it
    // reports is already confirmed.
    setGrade: () => {},
    updateThisComment: () => {},
    removeThisComment: () => {}
  };

  comments.forEach((commentData, index) => {
    const container = document.getElementById(`line-comment-${index}`);
    if (container) {
      const root = createRoot(container);
      root.render(
        <LineComment
          data={commentData}
          edit={true}
          actions={actions}
          gradeConfirmed={gradeConfirmed}
        />
      );
    }
  });
}

$(initConfirmReview);