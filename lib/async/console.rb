# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

module Async
	# Shims for the console gem, redirecting warnings and above to `Kernel#warn`.
	#
	# If you require this file, the `async` library will not depend on the `console` gem.
	#
	# That includes any gems that sit within the `Async` namespace.
	#
	# This is an experimental feature.
	module Console
		def self.debug(...)
		end
		
		def self.info(...)
		end
		
		def self.warn(*arguments, exception: nil, **options)
			if exception
				super(*arguments, exception.full_message, **options)
			else
				super(*arguments, **options)
			end
		end
		
		def self.error(...)
			self.warn(...)
		end
		
		def self.fatal(...)
			self.warn(...)
		end
	end
end
