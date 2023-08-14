class Sunniesnow::Convert::Converter

	def convert input, **opts
		convert_to_chart(input, **opts).to_json
	end

	def convert_to_chart input, **opts
		raise NotImplementedError
	end

end
