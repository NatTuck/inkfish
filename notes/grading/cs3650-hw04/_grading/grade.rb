#!/usr/bin/env ruby

require 'steno'

fs = [
  'test.pl',
  'Makefile',
  'data/ls0.txt',
  'data/ls1.txt',
  'data/ls2.txt',
  'data/tt0.txt',
  'data/tt1.txt',
  'data/tt2.txt',
  'data/words10.txt',
  'data/words1.txt',
  'data/words.txt',
]

steno = Steno.new
steno.save_grading_hashes(fs)
steno.unpack
steno.shell("make")
steno.check_grading_hashes
fs.each do |name|
  FileUtils.cp("_grading/#{name}", ".")
end
steno.run_tests("perl test.pl")

