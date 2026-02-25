import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import { Button, Form } from 'react-bootstrap';
import { Map, Set } from 'immutable';
import _ from 'lodash';

export function TeamSuggestions({data, active}) {
  let sections = data.course.sections;
  if (sections.length == 0) {
    sections = sections.concat("default");
  }

  var suggs = sections.map((sec) => (
    <div key={sec}>
      <h3>Section {sec}</h3>
      <SectionSuggestions data={data} active={active} section={sec} />
    </div>
  ));

  return (<div>{suggs}</div>);
}

// Filter students by attendance status
export function filterStudentsByAttendance(regs, attendanceMap) {
  const presentIds = new Set();
  
  if (attendanceMap) {
    for (const [reg, att] of attendanceMap) {
      if (att && (att.status === 'present' || att.status === 'late' || att.status === 'on time')) {
        presentIds.add(reg.id);
      }
    }
  }
  
  console.log('presentIds:', presentIds);
  console.log('regs:', regs);
  
  const result = regs.filter(reg => {
    const isIncluded = presentIds.has(reg.id);
    console.log(`Checking reg.id=${reg.id}, presentIds.has(${reg.id})=${isIncluded}`);
    return isIncluded;
  });
  
  console.log('Filtered result:', result);
  
  return result;
}

function SectionSuggestions({data, active, section}) {
  let [pairs, setPairs] = useState([]);

  let busy = Set();
  for (let team of active) {
    for (let reg of team.regs) {
      busy = busy.add(reg.user_id);
    }
  }

  // Filter to only present students based on attendance
  let presentRegs = [];
  if (data.meeting && data.meeting.students) {
    presentRegs = filterStudentsByAttendance(data.course.regs, data.meeting.students);
  } else {
    // If no meeting or attendance data, include all students
    presentRegs = data.course.regs;
  }

  let names = Map();
  let students = [];
  for (let reg of presentRegs) {
    // Only include students who are:
    // 1. Actually students
    // 2. Not already in active teams
    // 3. In the correct section
    if (reg.is_student && !busy.has(reg.user_id) &&
        (reg.section == section || section == "default")) {
      let user = reg.user;
      names = names.set(user.id, user.name);
      students.push(user.id);
    }
  }
  
  let pastTeams = Map();
  for (let team of data.past) {
    let tt = Set();
    for (let user of team.users) {
      tt = tt.add(user.id);
    }
    pastTeams = pastTeams.update(tt, 0, (xx) => xx + 1);
  }

  function reroll_teams() {
    setPairs(suggest_pairs(students, pastTeams));
  }
  
  useEffect(reroll_teams, []);

  let suggs = pairs.map((pair) => {
    let memberNames = pair.toArray().map((id) => names.get(id)).join(", ");
    let score = pastTeams.get(pair, 0);
    return (
      <li key={pair}>
        {memberNames} {score}
      </li>
    );
  });

  return (
    <div>
      <div className="my-3">
        <Button onClick={reroll_teams}>Reroll</Button>
      </div>
      <ul>
        {suggs}
      </ul>
    </div>
  );
}

export function suggest_pairs(students, pastTeams) {
  if (students.length == 0) {
    return [];
  }

  if (students.length <= 2) {
    return [Set(students)];
  }

  students = _.shuffle(students);

  let aa = students[0];
  let others = _.drop(students, 1);

  let teams = [];
  for (let bb of others) {
    teams.push(Set([aa, bb]));
  }

  let best = _.minBy(teams, (tt) => pastTeams.get(tt, 0));
  let rest = _.filter(students, (st) => !best.has(st));
  return [best].concat(suggest_pairs(rest, pastTeams));
}
