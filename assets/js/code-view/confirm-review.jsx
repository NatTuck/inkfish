import React from 'react';
import { createRoot } from 'react-dom/client';
import $ from 'cash-dom';

import LineComment from './line-comment';

function initConfirmReview() {
  const comments = window.confirm_review_comments || [];
  const gradeId = window.confirm_review_grade_id;
  const gradeConfirmed = window.confirm_review_grade_confirmed;

  const actions = {
    setGrade: (grade) => {
      console.log('setGrade', grade);
    },
    updateThisComment: (comment) => {
      console.log('updateThisComment', comment);
    },
    removeThisComment: () => {
      console.log('removeThisComment');
    }
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