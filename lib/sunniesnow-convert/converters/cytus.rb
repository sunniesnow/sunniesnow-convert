class Sunniesnow::Convert::Cytus < Sunniesnow::Convert::Converter

	class Chart

		class Note
			attr_reader :id
			attr_accessor :time, :x, :duration, :link

			def initialize id, time, x, duration
				@id = id
				@time = time
				@x = x
				@duration = duration
			end
		end

		attr_reader :notes

		def initialize input
			@contents = input.lines chomp: true
			@notes = []
			@link_count = 0

			read
		end

		def read
			@contents.each do |line|
				function, *args = line.split /\s+/
				case function
				when 'VERSION'
					@version = args[0]
				when 'BPM'
					@bpm = args[0].to_f
				when 'PAGE_SHIFT'
					@page_shift = args[0].to_f
				when 'PAGE_SIZE'
					@page_size = args[0].to_f
				when 'NOTE'
					add_note *args
				when 'LINK'
					add_link args.map &:to_i
				end
			end
		end

		def add_note id, time, x, duration
			id = id.to_i
			@notes[id] = Note.new id, time.to_f, x.to_f, duration.to_f
		end

		def add_link ids
			ids.each { @notes[_1].link = @link_count }
			@link_count += 1
		end

		def y_at time, top: 50, bottom: -50
			page, progress = ((time + @page_shift) / @page_size).divmod 1
			if page % 2 == 0
				bottom + progress * (top - bottom)
			else
				top - progress * (top - bottom)
			end
		end

		def x_at x, left: -100, right: 100
			left + x * (right - left)
		end
	end

	def initialize top: 50, bottom: -50, left: -100, right: 100
		@top = top
		@bottom = bottom
		@left = left
		@right = right
	end

	def convert input, **opts
		convert_to_chart(input, **opts).to_json
	end

	def convert_to_chart input, title: '', artist: '', difficulty_name: :hard, difficulty: 0
		difficulty_name = difficulty_name.downcase.to_sym
		chart = Chart.new input
		result = ::Sunniesnow::Chart.new
		result.title = title
		result.artist = artist
		result.charter = 'Rayark & sunniesnow-convert'
		result.difficulty_name = difficulty_name.to_s.upcase
		result.difficulty = difficulty.to_s
		result.difficulty_color = {easy: '#00ff00', hard: '#ff00ff'}[difficulty_name]
		chart.notes.each do |note|
			type = note.link ? :drag : note.duration > 0 ? :hold : :tap
			event = ::Sunniesnow::Chart::Event.new note.time, type
			event[:tipPoint] = note.link.to_s if note.link
			event[:x] = chart.x_at note.x, left: @left, right: @right
			event[:y] = chart.y_at note.time, top: @top, bottom: @bottom
			event[:duration] = note.duration if note.duration > 0
			result.events.push event
		end
		result
	end
end
