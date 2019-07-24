
fibers = []

(1..).each do |i|
	fibers << Fiber.new{}
	fibers.last.resume
	puts i
end

