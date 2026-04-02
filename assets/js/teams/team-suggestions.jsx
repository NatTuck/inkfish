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
  let presentIds = Set();
  
  if (attendanceMap) {
    for (const [reg, att] of attendanceMap) {
      if (att && att.status && att.status !== 'excused') {
        presentIds = presentIds.add(reg.id);
      }
    }
  }
  
  return regs.filter(reg => presentIds.has(reg.id));
}

function SectionSuggestions({data, active, section}) {
  let [pairs, setPairs] = useState([]);

  let busy = Set();
  for (let team of active) {
    for (let reg of team.regs) {
      busy = busy.add(reg.user_id);
    }
  }

  let presentRegs = [];
  if (data.meeting && data.meeting.students) {
    presentRegs = filterStudentsByAttendance(data.course.regs, data.meeting.students);
  } else {
    presentRegs = data.course.regs;
  }

  let names = Map();
  let students = [];
  for (let reg of presentRegs) {
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

  useEffect(() => {
    setPairs(prevPairs => {
      const currentIds = Set(prevPairs.flatMap(pair => pair.toArray()));
      const studentSet = Set(students);
      const newStudents = studentSet.subtract(currentIds).toArray();

      return add_new_students_to_suggestions(prevPairs, newStudents, pastTeams);
    });
  }, [students, pastTeams]);

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

export function add_new_students_to_suggestions(prevPairs, newStudents, pastTeams) {
  if (newStudents.length === 0) {
    return prevPairs;
  }

  let updatedPairs = prevPairs;

  for (const studentId of newStudents) {
    let added = false;

    for (let i = 0; i < updatedPairs.length; i++) {
      const pair = updatedPairs[i];
      if (pair.size === 1) {
        const potentialTeam = pair.add(studentId);
        if (pastTeams.get(potentialTeam, 0) === 0) {
          updatedPairs = [
            ...updatedPairs.slice(0, i),
            potentialTeam,
            ...updatedPairs.slice(i + 1)
          ];
          added = true;
          break;
        }
      }
    }

    if (!added) {
      updatedPairs = [...updatedPairs, Set([studentId])];
    }
  }

  return updatedPairs;
}
