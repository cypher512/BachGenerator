# quantize.rb: Written by Tadayoshi Funaba 1999-2005
# $Id: quantize.rb,v 1.1 2005-07-09 07:36:31+09 tadf Exp $

module SMF

  class Quantize

    def initialize(div, unit=1.0/8)
      @unit = unit * div * 4
      self.min = 0.0
      self.max = 1.0
      self.rand = 0.0
    end

    def min=(v) @min = @unit * v end
    def max=(v) @max = @unit * v end
    def rand=(v) @rand = @unit * v end

    def quantize(ev)
      offset = (ev.offset + @unit / 2) / @unit * @unit
      if @rand != 0
	offset += rand(@rand) - @rand / 2
      end
      offset = offset.round
      if (@min..@max) === (ev.offset - offset).abs
	ev.offset = offset
      end
    end

  end

end
