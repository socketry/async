# frozen_string_literal: true

require 'async/waiter'

require_relative 'barrier_examples'

RSpec.describe Async::Waiter do
	include_context Async::RSpec::Reactor

	it_behaves_like 'barrier'
end
