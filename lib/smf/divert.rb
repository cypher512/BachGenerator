# divert.rb: Written by Tadayoshi Funaba 2000, 2001
# $Id: divert.rb,v 1.3 2001-04-01 19:47:51+09 tadf Exp $

module SMF

  class Track

    def divert(sq)
      each do |ev|
	n = yield ev
	if n
	  sq[n] ||= Track.new
	  sq[n] << ev
	end
      end
      self
    end

  end

end
