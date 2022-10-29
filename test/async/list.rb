# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2022, by Shannon Skipper.

require 'async/list'

class Item < Async::List::Node
	def initialize(value)
		super()
		@value = value
	end
	
	attr_accessor :value
end

describe Async::List do
	let(:list) {Async::List.new}
	
	it "can append items" do
		list.append(Item.new(1))
		list.append(Item.new(2))
		list.append(Item.new(3))
		
		expect(list.each.map(&:value)).to be == [1, 2, 3]
	end
	
	it "can prepend items" do
		list.prepend(Item.new(1))
		list.prepend(Item.new(2))
		list.prepend(Item.new(3))
		
		expect(list.each.map(&:value)).to be == [3, 2, 1]
	end
	
	it "can remove items" do
		item = Item.new(1)
		
		list.append(item)
		list.delete(item)
		
		expect(list.each.map(&:value)).to be(:empty?)
	end
	
	it "can remove items from the middle" do
		item = Item.new(1)
		
		list.append(Item.new(2))
		list.append(item)
		list.append(Item.new(3))
		
		list.delete(item)
		
		expect(list.each.map(&:value)).to be == [2, 3]
	end
end
