import React, { useState, useCallback, useMemo } from 'react';
import ReactDOM from 'react-dom';
import { createRoot } from 'react-dom/client';
import { freeze } from 'icepick';
import _ from 'lodash';
import $ from 'cash-dom';

import { TeamSuggestions } from './team-suggestions';
import * as ajax from './ajax';
import socket from '../socket';

export default function init() {
  let root_div = document.getElementById('team-manager');
  if (root_div) {
    let root = createRoot(root_div);
    let data = window.teamset_data;
    let past = window.past_teams;
    let meeting = window.meeting;
    if (meeting) {
      meeting.students = window.attendances;
    }
    data.new_team_regs = [];
    data.past = past;
    data.meeting = meeting;
    root.render(<TeamManager data={data} />);
  }
}

function TeamManager({data: initialData}) {
  const [state, setState] = useState(() => {
    let state = Object.assign({}, initialData);
    state.creating = false;
    return freeze(state);
  });
  
  // Refs for channel and data
  const attendanceChannelRef = React.useRef(null);
  
  // Effect to setup channel connection
  React.useEffect(() => {
    const channel = socket.channel(`attendance:${state.course.id}`, {
      token: window.user_token
    });
    
    channel.join()
      .receive("ok", handleAttendanceState)
      .receive("error", msg => console.error("Channel error", msg));
    
    channel.on("state", handleAttendanceState);
    channel.on("team_update", handleTeamUpdate);
    
    attendanceChannelRef.current = channel;
    
    // Cleanup on unmount
    return () => {
      channel.leave();
    };
  }, [state.course.id]);
  
  // Handlers
  const handleAttendanceState = useCallback((stateData) => {
    setState(prev => freeze({
      ...prev,
      meeting: { ...prev.meeting, students: stateData.meeting.attendances }
    }));
  }, []);
  
  const handleTeamUpdate = useCallback((data) => {
    // Refresh teams list or update specific team
    loadTeams();
  }, []);
  
  // Convert class methods to functions
  const remove_member = useCallback((reg) => {
    console.log("remove", reg);
    setState(prev => {
      let regs = _.filter(
        prev.new_team_regs,
        (rr) => (rr.id != reg.id)
      );
      return freeze({
        ...prev,
        new_team_regs: regs,
      });
    });
  }, []);
  
  const add_member = useCallback((reg) => {
    console.log("add", reg);
    setState(prev => {
      let regs = _.concat(prev.new_team_regs, reg);
      return freeze({
        ...prev,
        new_team_regs: regs,
      });
    });
  }, []);
  
  const reset_data = useCallback((data) => {
    setState(prev => freeze({
      ...prev,
      ...data,
      new_team_regs: [],
      creating: false
    }));
  }, []);
  
  const createTeam = useCallback((ev) => {
    ev.preventDefault();
    
    setState(prev => freeze({
      ...prev,
      creating: true
    }));

    ajax.create_team(state.id, state.new_team_regs)
      .then((data) => {
        console.log("created", data);
        reset_data(data.data.teamset);
        
        // After successful creation, push to channel
        if (attendanceChannelRef.current) {
          attendanceChannelRef.current.push("team_created", { team: data.data.team });
        }
      });
  }, [state.id, state.new_team_regs, reset_data]);
  
  const toggleActive = useCallback((team, active) => {
    ajax.set_active_team(team, active)
      .then((data) => {
        console.log("set_active", data);
        reset_data(data.data.teamset);
        
        // After successful update, push to channel
        if (attendanceChannelRef.current) {
          attendanceChannelRef.current.push("team_updated", { team: data.data.team });
        }
      });
  }, [reset_data]);
  
  const destroyTeam = useCallback((team) => {
    ajax.delete_team(team)
      .then((data) => {
        console.log("deleted", data);
        reset_data(data.data.teamset);
        
        // After successful deletion, push to channel
        if (attendanceChannelRef.current) {
          attendanceChannelRef.current.push("team_deleted", { team: {id: team.id} });
        }
      });
  }, [reset_data]);
  
  const student_teams_map = useCallback(() => {
    let student_teams = new Map();
    for (let reg of state.course.regs) {
      if (reg.is_student) {
        student_teams.set(reg.id, []);
      }
    }

    for (let team of state.teams) {
      if (team.active) {
        for (let reg of team.regs) {
          let xs = student_teams.get(reg.id) || [];
          xs.push(team);
          student_teams.set(reg.id, xs);
        }
      }
    }

    return student_teams;
  }, [state.course.regs, state.teams]);
  
  const extra_students = useCallback(() => {
    let student_teams = student_teams_map();
    let new_regs = state.new_team_regs;
    let new_ids = new Set(_.map(new_regs, (reg) => reg.id));
    return _.filter(state.course.regs, (reg) => {
      let ts = student_teams.get(reg.id);
      return reg.is_student && ts.length == 0 && !new_ids.has(reg.id);
    });
  }, [state.course.regs, state.new_team_regs, student_teams_map]);
  
  const active_teams = useCallback(() => {
    return _.filter(state.teams, (team) => team.active);
  }, [state.teams]);
  
  const inactive_teams = useCallback(() => {
    return _.filter(state.teams, (team) => !team.active);
  }, [state.teams]);
  
  // Load teams function (to be implemented)
  const loadTeams = useCallback(() => {
    // TODO: Implement loading teams from server
    console.log("Loading teams...");
  }, []);
  
  // Memoize computed values
  const extraStudents = useMemo(() => extra_students(), [extra_students]);
  const activeTeams = useMemo(() => active_teams(), [active_teams]);
  const inactiveTeams = useMemo(() => inactive_teams(), [inactive_teams]);

  return (
    <div>
      <div className="row">
        <div className="col">
          <h2>Active Teams</h2>
          <TeamTable root={{toggleActive, destroyTeam}} teams={activeTeams} />

          <h2>Inactive Teams</h2>
          <TeamTable root={{toggleActive, destroyTeam}} teams={inactiveTeams} />
        </div>
        <div className="col">
          <h2>New Team</h2>
          <RegTable root={{add_member, remove_member}}
                    regs={state.new_team_regs}
                    controls={RemoveFromTeam} />
          <button className="btn btn-primary"
                  disabled={state.creating}
                  onClick={createTeam}>
            Create Team
          </button>
          
          <h2>Extra Students</h2>
          <RegTable root={{add_member}} regs={extraStudents} controls={AddToTeam}/>
        </div>
      </div>

      <div className="row">
        <div className="col">
          <h2>Suggested Teams</h2>
          <TeamSuggestions data={state} active={activeTeams} />
        </div>
        <div className="col">
          <h2>Who's Here?</h2>
          <WhosHere meeting={state.meeting} />
        </div>
      </div>
    </div>
  );
}

export function WhosHere({meeting}) {
  if (!meeting) {
    return (<p>No active meeting.</p>);
  }

  let rows = _.map(meeting.students, ([reg, att]) => (
    <tr key={reg.id}>
      <td>{reg.user.name}</td>
      <td>{att ? "here" : "missing"}</td>
    </tr>
  ));

  return (
    <div>
      <p>Code: {meeting.secret_code}</p>
      <table className="table table-striped">
        <tbody>
          {rows}
        </tbody>
      </table>
    </div>
  );
}

function RegTable({root, regs, controls}) {
  let Controls = controls;
  let rows = _.map(regs, (reg) => (
    <tr key={reg.id}>
      <td>{reg.user.name}</td>
      <td><Controls root={root} reg={reg} /></td>
    </tr>
  ));

  return (
    <table className="table table-striped">
      <tbody>
        {rows}
      </tbody>
    </table>
  );
}

function AddToTeam({root, reg}) {
  let on_click = (_ev) => {
    root.add_member(reg);
  };

  return (
    <button className="btn btn-secondary btn-sm"
            onClick={on_click}>
      Add
    </button>
  );
}

function RemoveFromTeam({root, reg}) {
  let on_click = (_ev) => {
    root.remove_member(reg);
  };

  return (
    <button className="btn btn-danger btn-sm"
            onClick={on_click}>
      Remove
    </button>
  );
}

function TeamTable({root, teams}) {
  let rows = _.map(teams, (team) => (
    <TeamRow key={team.id} root={root} team={team} />
  ));

  return (
    <table className="table table-striped">
      <thead>
        <tr>
          <th>#</th>
          <th>Members</th>
          <th>Subs</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {rows}
      </tbody>
    </table>
  );
}

function TeamRow({root, team}) {
  let members = _.map(team.regs, (reg) => reg.user.name);
  return (
    <tr>
      <td>#{team.id}</td>
      <td>{members.join(', ')}</td>
      <td>{team.subs.length}</td>
      <td><TeamControls root={root} team={team} /></td>
    </tr>
  );
}

function TeamControls({root, team}) {
  let btns = [];

  if (team.active) {
    btns.push(
      <button key="deact"
              className="btn btn-secondary btn-sm"
              onClick={() => root.toggleActive(team, false)}>
        Deactivate
      </button>
    );
  }
  else {
    btns.push(
      <button key="act"
              className="btn btn-secondary btn-sm"
              onClick={() => root.toggleActive(team, true)}>
        Activate
      </button>
    );
  }

  if (team.subs.length == 0) {
    btns.push(
      <button key="delete"
              className="btn btn-danger btn-sm"
              onClick={() => root.destroyTeam(team)}>
        Delete
      </button>
    );
  }

  return <div>{btns}</div>;
}

$(init);
