# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# Copyright, 2018, by Sokolov Yura aka funny-falcon
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

RSpec.describe Enumerator do
	def some_yielder(task)
		yield 1
		task.sleep(0.002)
		yield 2
	end

	def enum(task)
		to_enum(:some_yielder, task)
	end

	it "should play well with Enumerator as internal iterator" do
		# no fiber really used in internal iterator,
		# but let this test be here for completness
		ar = nil
		Async::Reactor.run do |task|
			ar = enum(task).to_a
		end
		expect(ar).to be == [1, 2]
	end

	it "should play well with Enumerator as external iterator", pending: "expected failure" do
		ar = []
		Async::Reactor.run do |task|
			en = enum(task)
			ar << en.next
			ar << en.next
			ar << begin en.next rescue $! end
		end
		expect(ar[0]).to be == 1
		expect(ar[1]).to be == 2
		expect(ar[2]).to be_a StopIteration
	end

	it "should play well with Enumerator.zip(Enumerator) method", pending: "expected failure" do
		Async::Reactor.run do |task|
			ar = [:a, :b, :c, :d].each.zip(enum(task))
			expect(ar).to be == [[:a, 1], [:b, 2], [:c, nil], [:d, nil]]
		end
	end

	it "should play with explicit Fiber usage", pending: "expected failure" do
		ar = []
		Async::Reactor.run do |task|
			fib = Fiber.new {
				Fiber.yield 1
				task.sleep(0.002)
				Fiber.yield 2
			}
			ar << fib.resume
			ar << fib.resume
			ar << fib.resume
			ar << begin en.next rescue $! end
		end
		expect(ar[0]).to be == 1
		expect(ar[1]).to be == 2
		expect(ar[2]).to be nil
		expect(ar[3]).to be_a FiberError
	end
end