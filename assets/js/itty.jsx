import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';
import $ from 'cash-dom';

import socket from "./socket";

let channel;

function Itty({uuid}) {
  let [data, setData] = useState({});
  let channel;

  useEffect(() => {
    channel = socket.channel("itty:" + uuid);
    channel.join()
      .receive("ok", (msg) => {
        console.log("Joined", uuid, msg);
      })
      .receive("error", (msg) => {
        console.log("Unable to join", msg);
	channel.leave();
      });
    channel.on("block", (msg) => console.log("block", msg));
    channel.on("done", (msg) => console.log("done", msg));
  });

  return (
    <p>uuid = {uuid}</p>
  );
}

function init() {
  let root = document.getElementById('itty-root');
  if (!root) {
    return;
  }

  let uuid = root.dataset.uuid;
  ReactDOM.render(<Itty uuid={uuid} />, root);
}

$(init);
