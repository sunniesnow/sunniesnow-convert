class Sunniesnow::Convert::Converter

	def convert input, **opts
		raise NotImplementedError
	end

	def self.for game
		case game
		when 'cytus'
			Sunniesnow::Convert::Cytus.new
		end
	end
end
