# groove.rb: Written by Tadayoshi Funaba 2005,2006,2008
# $Id: groove.rb,v 1.3 2008-02-16 16:56:21+09 tadf Exp $

require 'gsl'

module SMF

  class Groove

    def initialize(div, pat)
      @unit = pat[-1] * div * 4
      x = []; y = []
      pat.each_with_index do |p, i|
	x << @unit / (pat.size - 1) * i
	y << p * div * 4
      end
      @x = GSL::Vector.alloc(x)
      @y = GSL::Vector.alloc(y)
      @interp = GSL::Interp.alloc('linear', pat.size)
      self.amount = 0.5
    end

    def amount=(v) @amount = v end

    def groove(ev)
      q, r = ev.offset.divmod(@unit)
      r2 = @interp.eval(@x, @y, r)
      r3 = r + (r2 - r) * @amount
      ev.offset = (q * @unit + r3).round
    end

  end

end
