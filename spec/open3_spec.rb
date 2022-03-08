
require 'async'
require 'open3'
require 'logger'

RSpec.describe Open3 do
	it "can log errors" do
		2.times do
			Sync do
				Open3.popen3(["ls", "-lah"]) {|i, o, e| o.read}
			end
		end
	end
end
