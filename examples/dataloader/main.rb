#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "async"
require_relative "dataloader"

Async do
	dataloader = Dataloader.new
	
	dataloader.load("https://www.google.com")
	dataloader.load("https://www.microsoft.com")
	dataloader.load("https://www.github.com")
	
	pp dataloader.wait_all
end
