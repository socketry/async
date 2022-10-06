#!/usr/bin/env ruby

require 'async'
require_relative 'dataloader'

Async do
	dataloader = Dataloader.new
	
	dataloader.load("https://www.google.com")
	dataloader.load("https://www.microsoft.com")
	dataloader.load("https://www.github.com")
	
	pp dataloader.wait_all
end