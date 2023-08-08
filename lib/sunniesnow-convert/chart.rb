require 'json'

class Sunniesnow::Chart

	class Event
		attr_accessor :time, :type
		attr_reader :properties

		def initialize time, type
			@time = time
			@type = type
			@properties = {}
		end

		def [] key
			@properties[key]
		end

		def []= key, value
			@properties[key] = value
		end

		def to_json *args
			{time: @time, type: @type, properties: @properties}.to_json
		end
	end

	attr_reader :events
	attr_accessor :title, :charter, :artist, :difficulty_name, :difficulty_color, :difficulty
	def initialize
		@title = ''
		@artist = ''
		@charter = ''
		@difficulty_name = ''
		@difficulty_color = '#000000'
		@difficulty = ''
		@events = []
	end

	def to_json *args
		{
			title: @title,
			artist: @artist,
			charter: @charter,
			difficultyName: @difficulty_name,
			difficultyColor: @difficulty_color,
			difficulty: @difficulty,
			events: @events
		}.to_json
	end

end
