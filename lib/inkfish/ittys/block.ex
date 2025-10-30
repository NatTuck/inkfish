defmodule Inkfish.Ittys.Block do
  @derive {Jason.Encoder, only: [:seq, :stream, :text, :length]}
  defstruct seq: nil,
            stream: :adm,
            text: "",
            length: 0

  alias __MODULE__

  def new(seq, stream, text) do
    %Block{
      seq: seq,
      stream: stream,
      text: text,
      length: String.length(text)
    }
  end
end
