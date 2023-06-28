import { sortBy, sortedUniqBy } from 'lodash';
import { createStore } from 'redux';

function reducer(state = { blocks: [], done: false }, action) {
  console.log("reducer", state, action);

  switch (action.type) {
  case 'blocks/set':
    return Object.assign({}, state, { blocks: action.data });
  case 'blocks/add':
    let bs = sortedUniqBy(
      sortBy(state.blocks.concat(action.data), ['seq']),
      (bb) => bb.seq
    );

    return Object.assign({}, state, { blocks: bs });
  case 'set':
    let { blocks, done } = action.data;
    if (blocks && done) {
      return Object.assign({}, state, { blocks, done });
    }
    else {
      return state;
    }
  case 'done/set':
    return Object.assign({}, state, { done: action.data });
  default:
    return state;
  }
}

let store = createStore(reducer);

export default store;

