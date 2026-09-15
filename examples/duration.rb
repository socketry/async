# frozen_string_literal: true

class Duration
	def initialize(value)
		@value = value
	end
	
	attr :value
	
	SUFFIX = ["s", "ms", "μs", "ns"]

	def zero?
		@value.zero?
	end

	def to_s
		return "0" if self.zero?
		
		unit = 0
		value = @value.to_f

		while value < 1.0 && unit < SUFFIX.size
			value = value * 1000.0
			unit = unit + 1
		end

		return "#{value.round(2)}#{SUFFIX[unit]}"
	end

	def / factor
		self.class.new(@value / factor)
	end

	def self.time
		t = Process.times
		return t.stime + t.utime + t.cstime + t.cutime
	end

	def self.measure
		t = self.time
		
		yield

		return self.new(self.time - t)
	end
end
