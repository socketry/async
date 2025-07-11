# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# The implementation lives in `queue.rb` but later we may move it here for better autoload/inference.
require_relative "queue"

module Async
	class LimitedQueue < Queue
		class << self
			remove_method :new
		end
	end
end
