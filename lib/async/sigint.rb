# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Async
	# Installs a compatibility SIGINT handler when Ruby's default SIGINT handling does not respect `Thread.handle_interrupt`.
	#
	# See <https://bugs.ruby-lang.org/issues/22133> for more context.
	module SIGINT
		# Whether this Ruby needs the compatibility SIGINT handler.
		def self.required?
			true
		end
		
		# Install the compatibility SIGINT handler, if needed.
		def self.install
			return unless required?
			
			previous = ::Signal.trap(:INT, "DEFAULT")
			
			if previous == "DEFAULT"
				::Signal.trap(:INT) do
					::Thread.main.raise(::Interrupt)
				end
			else
				::Signal.trap(:INT, previous)
			end
		end

		self.install
	end
	
	private_constant :SIGINT
end
