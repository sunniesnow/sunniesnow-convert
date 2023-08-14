class Sunniesnow::Convert::Cytus2 < Sunniesnow::Convert::Converter

	class Chart

		class Page

			class PositionFunction
				attr_reader :type
				attr_accessor :arguments

				def initialize type = 0, arguments = [1.0, 0.0]
					unless type == 0
						raise ArgumentError, "Invalid position function type: #{type}"
					end
					@type = type
					@arguments = arguments
				end

				def call progress
					reduced = progress * 2 - 1
					calculated = @arguments[0] * reduced + @arguments[1]
					(calculated + 1) / 2
				end
			end

			attr_reader :index, :notes
			attr_accessor :start_tick, :end_tick, :scan_line_direction
			attr_reader :position_function

			def initialize index, start_tick, end_tick, scan_line_direction, position_function = nil
				@index = index
				@notes = []
				@start_tick = start_tick
				@end_tick = end_tick
				@scan_line_direction = scan_line_direction
				@position_function = position_function || PositionFunction.new
				if scan_line_direction == 0
					raise ArgumentError, 'Scan line direction cannot be 0'
				end
			end

			def y_at tick
				y = (tick - @start_tick).to_f / (@end_tick - @start_tick)
				@position_function.(@scan_line_direction < 0 ? 1 - y : y)
			end
		end

		class Note

			attr_accessor :page_index, :type, :tick, :x, :has_sibling, :hold_tick, :next_id, :is_forward, :note_direction
			attr_reader :id, :page
			attr_accessor :link_id

			def initialize id, page
				@id = id
				@page = page
				@page.notes.push self
			end

			def y
				@page.y_at @tick
			end

			def end_tick
				@tick + @hold_tick
			end

			def sunniesnow_type
				%i[tap hold hold drag drag flick tap drag tap drag][@type]
			end

			def is_drop
				[8, 9].include? @type
			end

			def is_link
				[3, 4, 6, 7].include? @type
			end

			def is_hold
				[1, 2].include? @type
			end

			def is_flick
				@type == 5
			end
		end

		class Event

			attr_accessor :type, :args

			def initialize type, args
				@type = type
				@args = args
			end

			def text
				case @type
				when 0
					"SPEED UP"
				when 1
					"SPEED DOWN"
				when 8
					@args.split(?,).first
				end
			end
		end

		class EventOrder

			attr_accessor :tick
			attr_reader :event_list

			def initialize tick
				@tick = tick
				@event_list = []
			end
		end

		class Tempo

			attr_accessor :tick, :value

			def initialize tick, value
				@tick = tick
				@value = value
			end
		end

		attr_reader :format_version
		attr_reader :page_list, :tempo_list, :event_order_list, :note_list
		attr_accessor :time_base, :start_offset_time, :end_offset_time, :is_start_without_ui

		def initialize input
			@json = JSON.parse input, symbolize_names: true
			read
			set_links
		end

		def read
			@format_version = @json[:format_version]
			@time_base = @json[:time_base]
			@start_offset_time = @json[:start_offset_time]
			@end_offset_time = @json[:end_offset_time]
			@is_start_without_ui = @json[:is_start_without_ui]
			@page_list = @json[:page_list].map.with_index do |page_json, i|
				s = page_json[:start_tick]
				e = page_json[:end_tick]
				d = page_json[:scan_line_direction]
				pf = page_json[:PositionFunction]
				pf = Page::PositionFunction.new pf[:Type], pf[:Arguments] if pf
				Page.new i, s, e, d, pf
			end
			@tempo_list = @json[:tempo_list].map { Tempo.new _1[:tick], _1[:value] }
			@event_order_list = @json[:event_order_list].map do |event_order_json|
				result = EventOrder.new event_order_json[:tick]
				event_order_json[:event_list].each do |event_json|
					result.event_list.push Event.new event_json[:type], event_json[:args]
				end
				result
			end
			@note_list = @json[:note_list].map do |note_json|
				is_forward = note_json[:is_forward]
				page_index = note_json[:page_index]
				page = @page_list[is_forward ? page_index - 1: page_index]
				result = Note.new note_json[:id], page
				result.page_index = page_index
				result.type = note_json[:type]
				result.tick = note_json[:tick]
				result.x = note_json[:x]
				result.has_sibling = note_json[:has_sibling]
				result.hold_tick = note_json[:hold_tick]
				result.next_id = note_json[:next_id]
				result.is_forward = is_forward
				result.note_direction = note_json[:NoteDirection] || 0
				result
			end
		end

		def set_links
			@note_list.each do |note|
				next if !note.is_link || note.link_id
				head = note
				loop do
					head.link_id = note.id
					break if head.next_id < 0
					head = @note_list[head.next_id]
				end
			end
		end

		def time_at tick
			index = @tempo_list.rindex { _1.tick <= tick }
			start = @start_offset_time * @time_base
			index.times do |i|
				tempo = @tempo_list[i]
				start += (@tempo_list[i + 1].tick - tempo.tick) * tempo.value
			end
			tempo = @tempo_list[index]
			(start + (tick - tempo.tick) * tempo.value) / @time_base.to_f / 1e6
		end

	end

	DIFFICULTY_COLORS = {
		easy: '#2482B3',
		hard: '#BC2029',
		chaos: '#C721C7',
		glitch: '#00A96B',
		crash: '#fabf03',
		dream: '#919191',
		drop: '#000000'
	}

	attr_accessor :top, :bottom, :left, :right
	attr_accessor :drop_top, :drop_bottom, :drop_distance, :drop_time
	attr_accessor :text_duration

	def initialize top: 50, bottom: -50, left: -100, right: 100,
		drop_distance: 100, drop_time: 1.0, drop_top: top, drop_bottom: bottom,
		text_duration: 0.5
		@top = top
		@bottom = bottom
		@left = left
		@right = right
		@drop_top = drop_top
		@drop_bottom = drop_bottom
		@drop_distance = drop_distance
		@drop_time = drop_time
		@text_duration = text_duration
	end

	def convert_to_chart input, title: '', artist: '', difficulty_name: :chaos, difficulty: 0
		difficulty_name = difficulty_name.to_s.downcase.to_sym
		chart = Chart.new input
		result = ::Sunniesnow::Chart.new
		result.title = title
		result.artist = artist
		result.charter = 'Rayark & sunniesnow-convert'
		result.difficulty_name = difficulty_name.to_s.upcase
		result.difficulty = difficulty.to_s
		result.difficulty_color = DIFFICULTY_COLORS[difficulty_name]
		chart.page_list.each do |page|
			page.notes.each do |note|
				time = chart.time_at note.tick
				event = ::Sunniesnow::Chart::Event.new time, note.sunniesnow_type
				event[:x] = @left + note.x * (@right - @left)
				event[:y] = @bottom + note.y * (@top - @bottom)
				event[:tipPoint] = "l#{note.link_id}" if note.is_link
				event[:duration] = chart.time_at(note.end_tick) - time if note.is_hold
				event[:angle] = note.x < 0.5 ? Math::PI : 0 if note.is_flick
				result.events.push get_drop_event note, event if note.is_drop
				result.events.push event
			end
		end
		chart.event_order_list.each do |event_order|
			time = chart.time_at event_order.tick
			event_order.event_list.each do |event|
				next unless text = event.text
				result.events.push ::Sunniesnow::Chart::Event.new time, 'bigText', text: text, duration: @text_duration
			end
		end
		result
	end

	# note: Cytus II note
	# event: Sunniesnow event
	def get_drop_event note, event
		result = ::Sunniesnow::Chart::Event.new event.time, :placeholder
		result[:x] = event[:x]
		y = event[:y]
		result[:tipPoint] = event[:tipPoint] = "d#{note.id}"
		if note.note_direction == 0
			if y + @drop_distance <= @drop_top
				result[:y] = y + @drop_distance
				result.time -= @drop_time
			else
				result[:y] = @drop_top
				result.time -= @drop_time * (@drop_top - y) / @drop_distance
			end
		else
			if y - @drop_distance >= @drop_bottom
				result[:y] = y - @drop_distance
				result.time -= @drop_time
			else
				result[:y] = @drop_bottom
				result.time -= @drop_time * (y - @drop_bottom) / @drop_distance
			end
		end
		result
	end

end
