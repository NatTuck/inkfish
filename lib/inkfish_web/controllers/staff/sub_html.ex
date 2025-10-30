defmodule InkfishWeb.Staff.SubHTML do
  use InkfishWeb, :html

  import InkfishWeb.AgJobHTML, only: [ag_log: 1]

  embed_templates "sub_html/*"
end
