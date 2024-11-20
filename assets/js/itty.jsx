import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { AnsiUp } from 'ansi_up';
import parseHTML from 'html-react-parser';
import $ from 'cash-dom';
import _ from 'lodash';

import socket from './socket';
import store from './itty/store';

let channel = null;

export function withChannel(op) {
  if (channel) {
    op(channel);
  }
}

export function Itty({chan, uuid, token}) {
  const dispatch = useDispatch();
  const blocks = useSelector((state) => state.blocks);
  const done = useSelector((state) => state.done);
  console.log("blocks,done", blocks, done);

  useEffect(() => {
    channel = socket.channel(chan + ":" + uuid, {token});
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

function init() {
  let root_div = document.getElementById('itty-root');
  if (!root_div) {
    return;
  }

  let {uuid, chan, token} = root_div.dataset;
  chan ||= "itty";

  let root = ReactDOM.createRoot(root_div);
  root.render(
    <Provider store={store}>
      <Itty chan={chan} uuid={uuid} token={token} />
    </Provider>
  );
}

$(init);
