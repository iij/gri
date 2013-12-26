def q(*args)
  if $debug or $test
    STDERR.puts args.map {|item| item.inspect}.join(', ')
  end
end
