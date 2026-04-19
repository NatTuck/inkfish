const marked = function(text) {
  return `<p>${text}</p>`;
};

marked.use = function() {};
marked.setOptions = function() {};
marked.defaults = {};

export { marked };
export default marked;