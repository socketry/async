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
	
	with '#append' do
		it "can append items" do
			list.append(Item.new(1))
			list.append(Item.new(2))
			list.append(Item.new(3))
			
			expect(list.each.map(&:value)).to be == [1, 2, 3]
			expect(list.to_a.map(&:value)).to be == [1, 2, 3]
			expect(list.to_s).to be =~ /size=3/
		end
		
		it "can't append the same item twice" do
			item = Item.new(1)
			list.append(item)
			
			expect do
				list.append(item)
			end.to raise_exception(ArgumentError, message: be =~ /already in a list/)
		end
	end
	
	with '#prepend' do
		it "can prepend items" do
			list.prepend(Item.new(1))
			list.prepend(Item.new(2))
			list.prepend(Item.new(3))
			
			expect(list.each.map(&:value)).to be == [3, 2, 1]
		end
		
		it "can't prepend the same item twice" do
			item = Item.new(1)
			list.prepend(item)
			
			expect do
				list.prepend(item)
			end.to raise_exception(ArgumentError, message: be =~ /already in a list/)
		end
	end
	
	with '#remove' do
		it "can remove items" do
			item = Item.new(1)
			
			list.append(item)
			list.remove(item)
			
			expect(list.each.map(&:value)).to be(:empty?)
		end
		
		it "can't remove an item twice" do
			item = Item.new(1)
			
			list.append(item)
			list.remove(item)
			
			expect do
				list.remove(item)
			end.to raise_exception(ArgumentError, message: be =~ /not in a list/)
		end
		
		it "can remove an item from the middle" do
			item = Item.new(1)
			
			list.append(Item.new(2))
			list.append(item)
			list.append(Item.new(3))
			
			list.remove(item)
			
			expect(list.each.map(&:value)).to be == [2, 3]
		end
	end
	
	with '#each' do
		it "can iterate over nodes while deleting them" do
			nodes = [Item.new(1), Item.new(2), Item.new(3)]
			nodes.each do |node|
				list.append(node)
			end
			
			enumerated = []
			
			index = 0
			list.each do |node|
				enumerated << node
				
				# This tests that enumeration is tolerant of deletion:
				if index == 1
					# When we are indexing child 1, it means the current node is child 0 - deleting it shouldn't break enumeration:
					list.remove(nodes.first)
				end
				
				index += 1
			end
			
			expect(enumerated).to be == nodes
		end
		
		it "can get #first and #last while enumerating" do
			list.append(first = Item.new(1))
			list.append(last = Item.new(2))
			
			list.each do |item|
				if item.equal?(last)
					# This ensures the last node in the list is an iterator:
					list.remove(last)
					expect(list.last).to be == first
				end
			end
		end
	end
	
	with '#first' do
		it "can return the first item" do
			item = Item.new(1)
			
			list.append(item)
			list.append(Item.new(2))
			list.append(Item.new(3))
			
			expect(list.first).to be == item
		end
	end
	
	with '#last' do
		it "can return the last item" do
			item = Item.new(1)
			
			list.append(Item.new(2))
			list.append(Item.new(3))
			list.append(item)
			
			expect(list.last).to be == item
		end
	end
end
