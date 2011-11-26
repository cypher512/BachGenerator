# shuffle.rb: Written by Tadayoshi Funaba 2005,2006,2008
# $Id: shuffle.rb,v 1.4 2008-02-16 16:56:21+09 tadf Exp $

require 'gsl'

module SMF

  class Shuffle

    def initialize(div, unit=1.0/8)
      @unit = unit * div * 4
      self.amount = 0.5
    end

    def amount=(v)
=begin
      shift = @unit / 2 * v
      @x = GSL::Vector.alloc(0, @unit / 2,         @unit)
      @y = GSL::Vector.alloc(0, @unit / 2 + shift, @unit)
      @interp = Interp.alloc('linear', 3)
=end
#=begin
      qunit = @unit / 4
      shift = @unit / 4 * v
      @x = GSL::Vector.alloc(0, qunit, qunit*2, qunit*3, @unit)
      @y = GSL::Vector.alloc(0, qunit, qunit*2 + shift, qunit*3 + shift/2, @unit)
      @interp = GSL::Interp.alloc('linear', 5)
#=end
    end

    def shuffle(ev)
      q, r = ev.offset.divmod(@unit)
      r2 = @interp.eval(@x, @y, r)
      ev.offset = (q * @unit + r2).round
    end

  end

end
