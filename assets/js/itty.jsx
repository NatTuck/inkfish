import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import { createStore } from 'redux';
import { Provider, useDispatch, useSelector } from 'react-redux';
import $ from 'cash-dom';

import socket from "./socket";

let channel;

function Itty({uuid}) {
  const dispatch = useDispatch();
  const blocks = useSelector(({blocks}) => blocks);

  useEffect(() => {
    console.log("effect");

    channel = socket.channel("itty:" + uuid);
    channel.join()
      .receive("ok", (msg) => {
        console.log("Joined", uuid, msg);
	dispatch({type: 'blocks/set', data: msg.blocks});
      })
      .receive("error", (msg) => {
        console.log("Unable to join", msg);
	channel.leave();
      });
    channel.on("block", (msg) => {
      console.log("Block", uuid, msg);
      dispatch({type: 'blocks/add', data: msg});
    });
    channel.on("done", (msg) => console.log("done", msg));
  }, []);

  return (
    <>
      <p>uuid = {uuid}</p>
      <p>{JSON.stringify(blocks)}</p>
    </>
  );
}

function reducer(state = { blocks: [] }, action) {
  switch (action.type) {
  case 'blocks/set':
    return Object.assign({}, state, { blocks: action.data });
  case 'blocks/add':
    return Object.assign({}, state, { blocks: state.blocks.concat(action.data) });
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

  let uuid = root_div.dataset.uuid;
  let root = ReactDOM.createRoot(root_div);
  root.render(
    <Provider store={store}>
      <Itty uuid={uuid} />
    </Provider>
  );
}

$(init);
