class Sunniesnow::Convert::Cytus < Sunniesnow::Convert::Converter

	class Chart

		class Note
			attr_reader :id
			attr_accessor :time, :x, :duration, :link

			def initialize id, time, x, duration
				@id = id.to_i
				@time = time.to_f
				@x = x.to_f
				@duration = duration.to_f
			end
		end

		class Section
			attr_accessor :time, :duration, :type

			def initialize time, duration, type
				@time = time.to_f
				@duration = duration.to_f
				@type = {5 => :up, 4 => :down}[type.to_i]
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
				when 'NAME'
					@name = args[0]
				when 'BG_MUSIC'
					@bg_music = args[0]
				when 'BPM'
					@bpm = args[0].to_f
				when 'SHIFT'
					@shift = args[0].to_f
				when 'PAGE_SHIFT'
					@page_shift = args[0].to_f
				when 'PAGE_SIZE'
					@page_size = args[0].to_f
				when 'BLINK_SHIFT'
					@blink_shift = args[0].to_f
				when 'SCAN_MODE'
					@scan_mode = args[0]
				when 'SECTION'
					add_section *args
				when 'NOTE'
					add_note *args
				when 'LINK'
					add_link args.map &:to_i
				end
			end
		end

		def add_section time, duration, type
			@sections ||= []
			@sections.push Section.new time, duration, type
		end

		def add_note *args
			if @version == '2'
				@notes[args[0].to_i] = Note.new *args
			else
				# simultaneity: notes at the same time has different simultaneity id
				# type: 0 for tap, 1 for link start, 2 for hold, 3 for link body
				# link_next: note id of the nexted linked note; -1 for none
				id, simultaneity, time, type, x, link_next, duration = args
				id = id.to_i
				@notes[id] = note = Note.new id, time, x, duration
				return unless %w[1 3].include? type
				if link = @links&.find_index { _1.include? id }
					note.link = link
				end
				link_next = link_next.to_i
				return if link_next < 0
				@links ||= []
				if note.link
					@links[note.link].add link_next
				else
					note.link = @link_count
					@links.push Set[id, link_next]
					@link_count += 1
				end
			end
		end

		def add_link ids
			ids.each { @notes[_1].link = @link_count }
			@link_count += 1
		end

		def y_at time, top: 50, bottom: -50
			if @version == '2'
				page, progress = ((time + @page_shift) / @page_size).divmod 1
				if page % 2 == 0
					bottom + progress * (top - bottom)
				else
					top - progress * (top - bottom)
				end
			else
				section = @sections.find { time >= _1.time && time < _1.time + _1.duration }
				case section&.type
				when :up
					bottom + (time - section.time) / section.duration * (top - bottom)
				when :down
					top - (time - section.time) / section.duration * (top - bottom)
				else
					(top + bottom) / 2.0
				end
			end
		end

		def x_at x, left: -100, right: 100
			left + x * (right - left)
		end
	end

	attr_accessor :top, :bottom, :left, :right

	def initialize top: 50, bottom: -50, left: -100, right: 100
		@top = top
		@bottom = bottom
		@left = left
		@right = right
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
