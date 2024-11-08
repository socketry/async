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
		# Log a message at the debug level. The shim is silent.
		def self.debug(...)
		end
		
		# Log a message at the info level. The shim is silent.
		def self.info(...)
		end
		
		# Log a message at the warn level. The shim redirects to `Kernel#warn`.
		def self.warn(*arguments, exception: nil, **options)
			if exception
				super(*arguments, exception.full_message, **options)
			else
				super(*arguments, **options)
			end
		end
		
		# Log a message at the error level. The shim redirects to `Kernel#warn`.
		def self.error(...)
			self.warn(...)
		end
		
		# Log a message at the fatal level. The shim redirects to `Kernel#warn`.
		def self.fatal(...)
			self.warn(...)
		end
	end
end
