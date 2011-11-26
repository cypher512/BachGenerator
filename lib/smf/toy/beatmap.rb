# beatmap.rb: Written by Tadayoshi Funaba 2005,2006
# $Id: beatmap.rb,v 1.3 2006-11-10 21:58:21+09 tadf Exp $

require 'smf/toy/searchsegment'
require 'rational'

module SMF

  class BeatMap

    include SearchSegment

    def o2b(div, offset, sig)
      bl = (div * 4).to_r / sig[1]
      bar, mod = offset.divmod(bl * sig[0])
      beat, tick = mod.divmod(bl)
      [bar, beat, tick]
    end

    def b2o(div, bar, sig)
      bl = (div * 4).to_r / sig[1]
      bar[0] * (bl * sig[0]) + bar[1] * bl + bar[2]
    end

    private :o2b, :b2o

    def initialize(sq)
      @div = sq.division
      @map = [[0, [4, 4], 1]] # [[offset, [n, d], bar]]
      sq.each do |tr|
	tr.each do |ev|
	  case ev
	  when TimeSignature
	    offset = (ev.offset + @div / 2) / @div * @div
	    @map << [offset, [ev.nn, 1 << ev.dd], 0]
	  end
	end
      end
      i = 0
      @map = @map.sort_by{|x| [x[0], i += 1]}
      lx = nil
      @map.each do |x|
	if lx
	  bar, beat, tick = o2b(@div, x[0] - lx[0], lx[1])
	  if bar == 0 && beat == 0 && tick == 0
	    x[2] = lx[2]
	  else
	    x[2] = lx[2] + bar
	  end
	end
	lx = x
      end
    end

    def offset2beat(offset)
      i = search_segment(@map){|x| x[0] <=> offset}
      lx = @map[i]
      bar, beat, tick = o2b(@div, offset - lx[0], lx[1])
      bar += lx[2]
      [bar, beat + 1, tick.round]
    end

    def beat2offset(bar)
      i = search_segment(@map){|x| x[2] <=> bar[0]}
      lx = @map[i]
      bar2 = [bar[0] - lx[2], bar[1] - 1, bar[2]]
      offset = lx[0] + b2o(@div, bar2, lx[1])
      offset.round
    end

  end

end
