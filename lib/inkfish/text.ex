defmodule Inkfish.Text do
  def replace_invalid_char(ch) do
    if (String.valid?(ch)) do
      ch
    else
      "\u{2622}" # RADIOACTIVE SIGN
    end
  end

  def corrupt_invalid_utf8(text) do
    text
    |> String.codepoints
    |> Enum.map(&replace_invalid_char/1)
    |> Enum.join("")
  end

  def sha256(text) do
    :crypto.hash(:sha256, text)
    |> Base.encode16()
    |> String.downcase()
  end

  def zeropad(n, k) do
    :io_lib.format("~*..0B", [k, n])
    |> to_string()
  end

  def gen_uuid() do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16
  end

  def lines([]), do: []
  def lines(text) when is_binary(text) do
    text
    |> String.graphemes()
    |> lines()
  end
  def lines(xs) when is_list(xs) do
    ii = Enum.find_index(xs, &(&1 == "\n"))
    if ii do
      first = Enum.take(xs, ii + 1)
      rest = Enum.drop(xs, ii + 1)
      [Enum.join(first, "") | lines(rest)]
    else
      [Enum.join(xs, "")]
    end
  end
end
