#!/usr/bin/env ruby

require 'sqlite3'

require_relative '../../lib/async'

Async do
	s = "SELECT 1;"*500000
	db = SQLite3::Database.new(':memory:')
	db.execute_batch2(s)
end
