# frozen_string_literal: true

require 'sunniesnow-convert/converters/base'
require 'sunniesnow-convert/converters/cytus'
require 'sunniesnow-convert/converters/cytus2'
require 'sunniesnow-convert/converters/lyrica'

def (Sunniesnow::Convert::Converter).for game, **opts
	case game
	when 'cytus'
		Sunniesnow::Convert::Cytus.new **opts
	when 'cytus2'
		Sunniesnow::Convert::Cytus2.new **opts
	when 'lyrica'
		Sunniesnow::Convert::Lyrica.new **opts
	end
end
