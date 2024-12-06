defmodule Inkfish.Combos do
  def uniq_pairs_from(xs) do
    for aa <- xs, bb <- xs, aa < bb do
      {aa, bb}
    end
  end

  def permutations([]), do: [[]]

  def permutations(xs) do
    for x <- xs, rest <- permutations(xs -- [x]) do
      [x | rest]
    end
  end

  def all_possible_partners(xs) do
    if length(xs) <= 3 do
      [[Enum.sort(xs)]]
    else
      for aa <- xs, bb <- xs, aa < bb, rest <- all_possible_partners(xs -- [aa, bb]) do
        [[aa, bb] | rest]
      end
    end
  end
end
