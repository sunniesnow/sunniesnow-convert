class Sunniesnow::Convert::Lyrica < Sunniesnow::Convert::Converter

	class Chart
		class Event

			BG_PATTERNS = {
				a1: :grid, a2: :hexagon, a3: :checkerboard, a4: :diamondGrid, a5: :pentagon, a6: :turntable, a7: :hexagram
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
				@arg, @arg2 = args[5].split ?_
				@arg = @arg.to_f
				@arg2 = @arg2&.to_i
				@text = args[6]
				@tp_spawning = args[7].to_i
				@tp_ending = args[8].to_i == 1
				if @tp_spawning % 20 >= 10 && args[8].nil?
					@tp_spawning -= 10
					@tp_ending = true
				end
				@bg = bg
			end

			def sunniesnow_type
				if @bg
					@tp_channel == 40 ? BG_PATTERNS[@text.to_sym] : :bgNote
				else
					%i[drag tap tap flick hold][@type]
				end
				# TODO: showImage, covering type=11,12
			end

			def to_sunniesnow
				return unless type = sunniesnow_type
				result = ::Sunniesnow::Chart::Event.new @time, type
				result[:text] = @text if %i[tap flick hold bgNote bigText].include? type
				result[:duration] = @arg unless %i[tap flick drag].include? type
				result[:duration] = 0 if @bg && ![4, 11, 12].include?(@type)
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

		NO_TP_CHANNELS = [-100, -80]
		MAIN_CHANNEL = -60
		INDEPENDENT_CHANNEL = 20

		SLOW_TP_TIME = 1.5
		FAST_TP_TIME = 1.0
		MAX_TP_TIME = 2.0

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

		def add note, index
			result = actual_add note, index
			@current_index += 1
			result
		end

		def actual_add note, index
			return [] unless note
			return no_tp note if NO_TP_CHANNELS.include? note.tp_channel

			result = case b = note.tp_spawning
			when 0
				spawning_0_events note
			when 1
				spawning_1_events note
			when 2
				spawning_2_events note
			when 3
				spawning_3_events note
			when 4
				spawning_4_events note
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
			else
				warn "Unknown tp_spawning = #{b} at note #{index}"
				spawning_0_events note
			end
			end_tp_if_should note
			result
		end

		def rand_range min, max
			min + (max - min) * rand
		end

		def rand_bool
			rand < 0.5
		end

		def rand_sign
			rand_bool ? 1 : -1
		end

		# 继续游标链; 若超过 2s 则重新开始游标链
		def spawning_0_events note
			a = note.tp_channel
			if a == INDEPENDENT_CHANNEL
				spawn_at_last_main note
			elsif @last_notes[a]&.time&.>= note.time - MAX_TP_TIME
				continue_tp note
			else
				spawn_at_auto note
			end
		end

		# 从上次结束的地方引出游标
		def spawning_1_events note
			spawn_at_last_main note
		end

		# 小斜率随机
		def spawning_2_events note
			x = note.x > 0 ? (note.x-120).clamp(-100,0) : (note.x+120).clamp(0,100)
			y = rand_range -50, 50
			spawn_at note, x, y, :slow
		end

		# 大斜率随机
		def spawning_3_events note
			x = rand_range (note.x-40).clamp(-130,130), (note.x+40).clamp(-130,130)
			y = note.y > 0 ? -75 : 75
			spawn_at note, x, y, :slow
		end

		# 随机
		def spawning_4_events note
			if rand_bool
				x = (note.x.abs>50 ? note.x>0 : rand_bool) ? (note.x-120).clamp(-100,0) : (note.x+120).clamp(0,100)
				y = rand_range -50, 50
			else
				x = rand_range (note.x-40).clamp(-130,130), (note.x+40).clamp(-130,130)
				y = -80*(note.x.abs > 50 && note.y.abs > 20 ? note.y<=>0 : rand_sign)
			end
			spawn_at note, x, y, :slow
		end

		# 横外落
		def spawning_5_events note
			x = note.x > 0 ? (note.x-120).clamp(-100,0) : (note.x+120).clamp(0,100)
			spawn_at note, x, note.y, :slow
		end

		# 纵外落
		def spawning_6_events note
			y = note.y > 0 ? -100 : 100
			spawn_at note, note.x, y, :fast
		end

		# 上落
		def spawning_20_events note
			spawn_at note, note.x, note.y - 100, :fast
		end

		# 右上落
		def spawning_21_events note
			spawn_at note, note.x - 72, note.y - 72, :fast
		end

		# 右落
		def spawning_22_events note
			spawn_at note, note.x - 100, note.y, :fast
		end

		# 右下落
		def spawning_23_events note
			spawn_at note, note.x - 72, note.y + 72, :fast
		end

		# 下落
		def spawning_24_events note
			spawn_at note, note.x, note.y + 100, :fast
		end

		# 左下落
		def spawning_25_events note
			spawn_at note, note.x + 72, note.y + 72, :fast
		end

		# 左落
		def spawning_26_events note
			spawn_at note, note.x + 100, note.y, :fast
		end

		# 左上落
		def spawning_27_events note
			spawn_at note, note.x + 72, note.y - 72, :fast
		end

		def peek channel
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
			peek a
		end

		def spawn_at note, x, y, time
			a = note.tp_channel
			event = note.to_sunniesnow
			if time == :slow || time == :fast
				time = note.time - (time == :slow ? SLOW_TP_TIME : FAST_TP_TIME)
				if a != INDEPENDENT_CHANNEL && (last = @last_notes[a])
					time = [time, last.time].max
				end
			end
			spawning_event = ::Sunniesnow::Chart::Event.new time, :placeholder
			spawning_event[:x] = x
			spawning_event[:y] = y
			spawning_event[:tipPoint] = event[:tipPoint] = end_tp a
			@last_notes[a] = note
			@last_indices[a] = @current_index
			[spawning_event, event]
		end

		def spawn_at_last_main note
			if last = @last_notes[MAIN_CHANNEL]
				time = note.tp_channel == INDEPENDENT_CHANNEL ? note.time - SLOW_TP_TIME : [note.time - MAX_TP_TIME, last.time].max
				spawn_at note, last.x, last.y, time
			else
				spawn_at_auto note
			end
		end

		def spawn_at_auto note
			x = note.x > 0 ? (note.x-120).clamp(-100,0) : (note.x+120).clamp(0,100)
			y = rand_range -50, 50
			spawn_at note, x, y, note.time - SLOW_TP_TIME
		end

		def continue_tp note
			a = note.tp_channel
			event = note.to_sunniesnow
			event[:tipPoint] = peek a
			@last_notes[a] = note
			@last_indices[a] = @current_index
			[event]
		end

		def no_tp note
			[note.to_sunniesnow]
		end

		def end_tp channel
			a = channel
			if @last_notes[a]
				@last_notes[a] = nil
				bump a
			else
				peek a
			end
		end

		def end_tp_if_should note
			return unless note.tp_ending
			end_tp note.tp_channel
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

	def convert_to_chart input, title: nil, artist: nil, difficulty_name: 'Unknown', difficulty_sup: '', difficulty_color: nil, difficulty: '0', random: Random.new
		tp_manager = TipPointManager.new random
		chart = Chart.new input
		result = ::Sunniesnow::Chart.new
		result.title = title || chart.title
		result.artist = artist || chart.artist
		result.charter = 'RNOVA Studio & sunniesnow-convert'
		result.difficulty_name = difficulty_name.to_s
		result.difficulty = difficulty
		result.difficulty_color = difficulty_color || DIFFICULTY_COLORS[difficulty_name.to_s.downcase.to_sym]
		result.difficulty_sup = difficulty_sup
		chart.notes.each_with_index { result.events.push *tp_manager.add(_1, _2) }
		tp_manager.wrap_up
		chart.bg_events.each do |bg_event|
			event = bg_event.to_sunniesnow
			result.events.push event if event
		end
		result
	end

end
