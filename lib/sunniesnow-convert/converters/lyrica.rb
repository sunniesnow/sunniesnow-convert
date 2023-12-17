class Sunniesnow::Convert::Lyrica < Sunniesnow::Convert::Converter

	class Chart
		class Event

			BG_PATTERNS = {
				a1: :grid, a2: :hexagon, a3: :checkerboard, a4: :diamondGrid, a5: :pentagon, a6: :turntable
			}.tap { _1.default = :bigText }.freeze

			attr_accessor :time, :x, :y, :type, :arg, :text
			attr_accessor :tp_channel, :tp_spawning, :tp_ending
			attr_reader :bg

			def initialize input, bg
				args = input.split ?|
				@time = args[0].to_f
				@tp_channel = args[1].to_i
				@x = args[2].to_f
				@y = args[3].to_f
				@type = args[4].to_i
				@arg = args[5].to_f
				@text = args[6]
				@tp_spawning = args[7].to_i
				@tp_ending = args[8].to_i == 1
				@bg = bg
			end

			def sunniesnow_type
				@bg ? @tp_channel == 40 ? BG_PATTERNS[@text.to_sym] : :bgNote : %i[drag tap tap flick hold][@type]
			end

			def to_sunniesnow
				return unless type = sunniesnow_type
				result = ::Sunniesnow::Chart::Event.new @time, type
				result[:text] = @text if %i[tap flick hold bgNote bigText].include? type
				result[:duration] = @arg unless %i[tap flick drag].include? type
				result[:angle] = Math::PI/2 - @arg/180*Math::PI if type == :flick
				result[:x], result[:y] = @x, @y if %i[tap flick hold drag bgNote].include? type
				result
			end
		end

		attr_accessor :bpm, :title, :artist, :offset, :time_sig, :version
		attr_reader :notes, :bg_events, :legacy_events, :bpm_events

		def initialize input
			lines = input.lines chomp: true
			read_meta lines[0]
			@notes = read_events lines[2], false
			@bg_events = read_events lines[4], true
			@legacy_events = read_events lines[6], false
			@bpm_events = read_events lines[8], false
			pair_siblings
		end

		def read_meta input
			args = input.split ?|
			@bpm = args[0].to_f
			@title = args[1]
			@artist = args[2]
			@offset = args[3].to_f
			@time_sig = args[4].to_i
			@version = args[5].to_i
		end

		def read_events input, bg
			input.split(?,).map! { Event.new _1, bg }
		end

		def pair_siblings
			@notes.each_cons 3 do |previous_note, note, next_note|
				next unless note.type == 2
				next if (left = previous_note.type == 2) && previous_note.time == note.time
				next if (right = next_note.type == 2) && next_note.time == note.time
				if left && right
					note.time = [previous_note, next_note].min_by { (_1.time - note.time).abs }.time
				elsif left
					note.time = previous_note.time
				elsif right
					note.time = next_note.time
				end
			end
		end

	end

	class TipPointManager

		TIP_POINT_MOVING_SPEED = 100 # per second

		def initialize random = Random.new
			@random = random
			@last_ending_x = 0.0
			@last_ending_y = 0.0
			@last_notes = {} # key: channel id, value: a note
			@channel_id_bump = {} # key: channel id, value: bump
			@current_index = 0
			@last_ending_events = []
			@last_ending_indices = []
			@last_indices = {}
		end

		def add note
			result = actual_add note
			@current_index += 1
			result
		end

		def actual_add note
			return [] unless note
			return no_tp note unless can_have_tp? note

			b = note.tp_spawning
			return cancel_tp note, true if b == 10
			result = case b
			when 0
				spawning_0_events note
			when 2
				spawning_2_events note
			when 3
				spawning_3_events note
			when 4
				spawning_4_events note
			end
			unless result
				return cancel_tp note unless can_have_falling_tp? note
				result = case b
				when 1
					spawning_1_events note
				when 5
					spawning_5_events note
				when 6
					spawning_6_events note
				when 20
					spawning_20_events note
				when 21
					spawning_21_events note
				when 22
					spawning_22_events note
				when 23
					spawning_23_events note
				when 24
					spawning_24_events note
				when 25
					spawning_25_events note
				when 26
					spawning_26_events note
				when 27
					spawning_27_events note
				end
			end
			end_tp_if_should note
			result
		end

		# 继续游标链; 若超过 2s 则重新开始游标链
		def spawning_0_events note
			a = note.tp_channel
			if a == 20
				spawn_at_last_ending note
			elsif @last_notes[a]&.time&.>= note.time - 2
				continue_tp note
			else
				spawn_at note, x_tp_map(note.x), -50 + 100 * rand
			end
		end

		# 从上次结束的地方引出游标
		def spawning_1_events note
			spawn_at_last_ending note
		end

		# 小斜率随机
		def spawning_2_events note
			spawn_at note, x_tp_map(note.x), note.y + 50*(rand-0.5)
		end

		# 大斜率随机
		def spawning_3_events note
			spawn_at note, note.x + 100*(rand-0.5), y_tp_map(note.y)
		end

		# 随机
		def spawning_4_events note
			rho, phi = 50 + 25 * rand, 2 * Math::PI * rand
			spawn_at note, note.x + rho * Math.cos(phi), note.y + rho * Math.sin(phi)
		end

		# 横外落
		def spawning_5_events note
			spawn_at note, x_tp_map(note.x), note.y
		end

		# 纵外落
		def spawning_6_events note
			spawn_at note, note.x, y_tp_map(note.y)
		end

		# 上落
		def spawning_20_events note
			spawn_at note, note.x, note.y - 100
		end

		# 右上落
		def spawning_21_events note
			spawn_at note, note.x - 75, note.y - 75
		end

		# 右落
		def spawning_22_events note
			spawn_at note, note.x - 100, note.y
		end

		# 右下落
		def spawning_23_events note
			spawn_at note, note.x - 75, note.y + 75
		end

		# 下落
		def spawning_24_events note
			spawn_at note, note.x, note.y + 100
		end

		# 左下落
		def spawning_25_events note
			spawn_at note, note.x + 75, note.y + 75
		end

		# 左落
		def spawning_26_events note
			spawn_at note, note.x + 100, note.y
		end

		# 左上落
		def spawning_27_events note
			spawn_at note, note.x + 75, note.y - 75
		end

		def x_tp_map x
			return -x_tp_map(-x) if x > 0
			100.0 + (x/25.0 + 0.5).round(half: :even)
		end

		def y_tp_map y
			y > 0 ? -100.0 : 100.0
		end

		def seek channel
			a = channel
			"#{a} #{@channel_id_bump[a] ||= 0}"
		end

		def rand *args
			@random.rand *args
		end

		def bump channel
			a = channel
			@channel_id_bump[a] ||= 0
			@channel_id_bump[a] += 1
			seek a
		end

		def spawn_at note, x, y
			a = note.tp_channel
			event = note.to_sunniesnow
			spawning_event = ::Sunniesnow::Chart::Event.new note.time, :placeholder
			spawning_event[:x] = x
			spawning_event[:y] = y
			time = 1.0 # Math.hypot(x - note.x, y - note.y) / TIP_POINT_MOVING_SPEED
			spawning_event.time -= time > 1 ? 1 : time
			spawning_event[:tipPoint] = event[:tipPoint] = end_tp a
			@last_notes[a] = note
			@last_indices[a] = @current_index
			[spawning_event, event]
		end

		def spawn_at_last_ending note
			@last_ending_events[@current_index] = spawn_at note, @last_ending_x, @last_ending_y
		end

		def continue_tp note
			a = note.tp_channel
			event = note.to_sunniesnow
			event[:tipPoint] = seek a
			@last_notes[a] = note
			@last_indices[a] = @current_index
			[event]
		end

		def no_tp note
			[note.to_sunniesnow]
		end

		def end_tp channel, force_record_ending = false
			a = channel
			return seek a unless last = @last_notes[a]
			if a == -60 || force_record_ending
				@last_ending_x = last.x
				@last_ending_y = last.y
				(@last_indices[a] + 1...@current_index).each do |i|
					next unless @last_ending_events[i]
					next if @last_ending_indices[i]&.>= @last_indices[a]
					@last_ending_indices[i] = @last_indices[a]
					spawning_event, event = @last_ending_events[i]
					spawning_event[:x] = x = @last_ending_x
					spawning_event[:y] = y = @last_ending_y
					time = Math.hypot(x - event[:x], y - event[:y]) / TIP_POINT_MOVING_SPEED
					spawning_event.time = event.time - [time, 1].min
				end
			end
			@last_notes[a] = nil
			@last_indices[a] = nil
			bump a
		end

		def cancel_tp note, force_record_ending = false
			end_tp note.tp_channel, force_record_ending
			no_tp note
		end

		def end_tp_if_should note
			return unless note.tp_ending
			end_tp note.tp_channel
		end

		def can_have_falling_tp? note
			a = note.tp_channel
			return true if a == 20
			return true unless last = @last_notes[a]
			last.time < note.time - 1
		end

		def can_have_tp? note
			note.tp_channel.abs < 80
		end

		def wrap_up
			@last_notes.each_key { end_tp _1 }
		end
	end

	DIFFICULTY_COLORS = {
		easy: '#3eb9fd',
		normal: '#f19e56',
		hard: '#e75e74',
		master: '#8c68f3',
		special: '#f156ee'
	}

	def convert_to_chart input, title: nil, artist: nil, difficulty_name: :master, difficulty: 0
		tp_manager = TipPointManager.new
		difficulty_name = difficulty_name.to_s.downcase.to_sym
		chart = Chart.new input
		result = ::Sunniesnow::Chart.new
		result.title = title || chart.title
		result.artist = artist || chart.artist
		result.charter = 'RNOVA Studio & sunniesnow-convert'
		result.difficulty_name = difficulty_name.to_s.capitalize
		result.difficulty = difficulty.floor.to_s
		result.difficulty_color = DIFFICULTY_COLORS[difficulty_name]
		result.difficulty_sup = difficulty % 1 > 0.5 ? '+' : ''
		chart.notes.each { result.events.push *tp_manager.add(_1) }
		tp_manager.wrap_up
		chart.bg_events.each do |bg_event|
			event = bg_event.to_sunniesnow
			result.events.push event if event
		end
		result
	end

end
