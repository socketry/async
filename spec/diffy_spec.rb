
require 'async'
require 'diffy'
require 'logger'

RSpec.describe Diffy do
	def async_test_no_logfile
		Async do
			begin
				100.times do
					Diffy::Diff.new('hi there, how are?', 'hi there, how are you?').to_s(:html)
				end
			rescue => error
				Console.logger.error(error)
				pp error.backtrace
			end
		end
	end
	
	it "can log errors" do
		10.times do
			async_test_no_logfile
		end
	end
end
