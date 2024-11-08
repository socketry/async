# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "covered/sus"
include Covered::Sus

ENV["TRACES_BACKEND"] ||= "traces/backend/test"
ENV["METRICS_BACKEND"] ||= "metrics/backend/test"

def prepare_instrumentation!
	require "traces"
	require "metrics"
end

def before_tests(...)
	prepare_instrumentation!
	
	super
end
