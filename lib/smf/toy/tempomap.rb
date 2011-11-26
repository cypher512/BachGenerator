# tempomap.rb: Written by Tadayoshi Funaba 2005,2006
# $Id: tempomap.rb,v 1.2 2006-06-20 22:24:14+09 tadf Exp $

require 'smf/toy/searchsegment'
require 'rational'

module SMF

  class TempoMap

    include SearchSegment

    def o2e(div, offset, tempo)
      offset * (60.to_r/tempo) / div
    end

    def e2o(div, elapse, tempo)
      elapse * div / (60.to_r/tempo)
    end

    private :o2e, :e2o

    def initialize(sq)
      @div = sq.division
      @map = [[0, 120, 0]] # [[offset, bpm, elapse]]
      sq.each do |tr|
	tr.each do |ev|
	  case ev
	  when SetTempo; @map << [ev.offset, 60000000.to_r / ev.tempo, 0]
	  end
	end
      end
      i = 0
      @map = @map.sort_by{|x| [x[0], i += 1]}
      lx = nil
      @map.each do |x|
	if lx
	  s = o2e(@div, x[0] - lx[0], lx[1])
	  x[2] = lx[2] + s
	end
	lx = x
      end
    end

    def offset2elapse(offset)
      i = search_segment(@map){|x| x[0] <=> offset}
      lx = @map[i]
      elapse = lx[2] + o2e(@div, offset - lx[0], lx[1])
      elapse
    end

    def elapse2offset(elapse)
      i = search_segment(@map){|x| x[2] <=> elapse}
      lx = @map[i]
      offset = lx[0] + e2o(@div, elapse - lx[2], lx[1])
      offset.round
    end

    def elapse2frame(elapse, tc=30)
      hr, mod = elapse.divmod(3600.to_r)
      mn, mod = mod.divmod(60.to_r)
      se, mod = mod.divmod(1.to_r)
      fr, mod = mod.divmod(1.to_r/tc)
      ff, mod = mod.divmod(1.to_r/tc/100)
      [hr, mn, se, fr, ff]
    end

    def frame2elapse(frame, tc=30)
      frame[0] * 3600 + frame[1] * 60 + frame[2] +
	frame[3].to_r / tc + frame[4].to_r / (100 * tc)
    end

  end

end
