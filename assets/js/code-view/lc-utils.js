
import { v4 as uuid } from 'uuid';

export function same_lc(aa, bb) {
  return (aa.id && aa.id == bb.id) || (aa.uuid && aa.uuid == bb.uuid);
}

export function make_lc(line, path, grade, user) {
  console.log(user);
  return {line, path, grade, user,
          points: 0, text: "", uuid: uuid()};
}

export function lcs_del(lcs, lc) {
  return lcs.filter((xx) => !same_lc(xx, lc));
}

export function lcs_put(lcs, lc) {
  lcs = lcs_del(lcs, lc);
  return [...lcs, lc];
}

