# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require_relative 'condition'

module Async
	# A synchronization primitive that allows one task to wait for another task to resolve a value.
	class Variable
		# Create a new variable.
		#
		# @parameter condition [Condition] The condition to use for synchronization.
		def initialize(condition = Condition.new)
			@condition = condition
			@value = nil
		end
		
		# Resolve the value.
		#
		# Signals all waiting tasks.
		#
		# @parameter value [Object] The value to resolve.
		def resolve(value = true)
			@value = value
			condition = @condition
			@condition = nil
			
			self.freeze
			
			condition.signal(value)
		end
		
		# Whether the value has been resolved.
		#
		# @returns [Boolean] Whether the value has been resolved.
		def resolved?
			@condition.nil?
		end
		
		# Wait for the value to be resolved.
		#
		# @returns [Object] The resolved value.
		def value
			@condition&.wait
			return @value
		end
		
		# Alias for {#value}.
		def wait
			self.value
		end
	end
end
