# frozen_string_literal: true

threads = []

(1..).each do |i|
	threads << Thread.new{sleep}
	puts i
end

