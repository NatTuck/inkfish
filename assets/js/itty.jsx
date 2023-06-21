import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import { createStore } from 'redux';
import { Provider, useDispatch, useSelector } from 'react-redux';
import AnsiUp from 'ansi_up';
import parseHTML from 'html-react-parser';
import $ from 'cash-dom';
import _ from 'lodash';

import socket from "./socket";

let channel;

function Itty({uuid}) {
  const dispatch = useDispatch();
  const {blocks, done} = useSelector(({blocks, done}) => ({blocks, done}));
  console.log("blocks,done", blocks, done);

  useEffect(() => {
    channel = socket.channel("itty:" + uuid);
    channel.join()
      .receive("ok", (msg) => {
        console.log("Joined", uuid, msg);
	dispatch({type: 'set', data: msg});
      })
      .receive("error", (msg) => {
        console.log("Unable to join", msg);
	channel.leave();
      });
    channel.on("block", (msg) => {
      console.log("Block", uuid, msg);
      dispatch({type: 'blocks/add', data: msg});
    });
    channel.on("done", (msg) => {
      console.log("done", msg);
      dispatch({type: 'done/set', data: true});
    });
  }, []);

  useEffect(() => {
    let elem = document.getElementById('itty-console');
    if (elem.scrollHeight - elem.clientHeight < elem.scrollTop - 5) {
      console.log("no scroll");
      return;
    }
    elem.scrollTop = elem.scrollHeight - elem.clientHeight;
    console.log("scrolled");
  });

  let ansi_up = new AnsiUp();
  let lines = _.sortBy(blocks, ['seq']).map(({seq, text}) => (
    <span key={seq}>{parseHTML(ansi_up.ansi_to_html(text))}</span>
  ));
      
  return (
    <>
      <pre id="itty-console" className="console autograde-console">{ lines }</pre>
      {done ? "done" : "running"}
    </>
  );
}

function Icon({name}) {
  return (
    <img src={"/images/icons/" + name + ".svg"} />
  );
}

function reducer(state = { blocks: [], done: false }, action) {
  switch (action.type) {
  case 'blocks/set':
    return Object.assign({}, state, { blocks: action.data });
  case 'blocks/add':
    return Object.assign({}, state, { blocks: state.blocks.concat(action.data) });
  case 'set':
    let { blocks, done } = action.data;
    return Object.assign({}, state, { blocks, done });
  case 'done/set':
    return Object.assign({}, state, { done: action.data });
  default:
    return state;
  }
}

let store = createStore(reducer);

function init() {
  let root_div = document.getElementById('itty-root');
  if (!root_div) {
    return;
  }

  let {uuid, chan} = root_div.dataset;
  chan ||= "itty";

  let root = ReactDOM.createRoot(root_div);
  root.render(
    <Provider store={store}>
      <Itty chan={chan} uuid={uuid} />
    </Provider>
  );
}

$(init);
