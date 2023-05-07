// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//import "regenerator-runtime/runtime";
//import "core-js/stable";

import "phoenix_html";
import $ from 'cash-dom';

// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket";
import "./uploads";
import "./search";
import "./collapse";
import "./grades/number-input";
import "./code-view/init";
import "./dates/init";
import "./uploads/init";
import "./tasks/init";
import init_teams from "./teams/team-manager";
import init_autograde from './autograde';
import "./gcol";

function app_init() {
  init_autograde();
  init_teams();
}

$(app_init);
