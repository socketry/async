# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require_relative 'condition'

module Async
	class Variable
		def initialize(condition = Condition.new)
			@condition = condition
			@value = nil
		end
		
		def resolve(value = true)
			@value = value
			condition = @condition
			@condition = nil
			
			self.freeze
			
			condition.signal(value)
		end
		
		def resolved?
			@condition.nil?
		end
		
		def value
			@condition&.wait
			return @value
		end
		
		def wait
			self.value
		end
	end
end
