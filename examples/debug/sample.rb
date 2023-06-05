require 'async'

Async do |t|
  t.async do
    puts "1\n"
  end
  t.async do
    puts "2\n"
  end
end
