
import $ from 'domtastic';
import viewer from "./code-viewer";
import init_tree from "./file-tree";

$(function() {
  viewer.init();
  init_tree();
});
