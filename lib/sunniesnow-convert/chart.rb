require 'json'

class Sunniesnow::Chart

	class Event
		attr_accessor :time, :type
		attr_reader :properties

		def initialize time, type, **properties
			@time = time
			@type = type
			@properties = properties
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
	attr_accessor :title, :charter, :artist, :difficulty_name, :difficulty_color, :difficulty, :difficulty_sup
	def initialize
		@title = ''
		@artist = ''
		@charter = ''
		@difficulty_name = ''
		@difficulty_color = '#000000'
		@difficulty = ''
		@difficulty_sup = ''
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
			difficultySup: @difficulty_sup,
			events: @events
		}.to_json
	end

end
