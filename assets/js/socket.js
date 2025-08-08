
import {Socket} from "phoenix";

var socket = null;

if (window.user_token) {
  socket = new Socket("/socket", {params: {token: window.user_token}});
  socket.connect();
}

export default socket;

