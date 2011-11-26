# velcomp.rb: Written by Tadayoshi Funaba 2005,2006,2008
# $Id: velcomp.rb,v 1.3 2008-02-16 16:56:21+09 tadf Exp $

require 'gsl'

module SMF

  class VelComp

    def initialize
      self.gain = 0
      self.thresh = 80
      self.ratio = 0.9
    end

    def init
      max = @thresh + (127 - @thresh) * @ratio
      @x = GSL::Vector.alloc(0, @thresh, 127)
      @y = GSL::Vector.alloc(0, @thresh, max)
      @interp = GSL::Interp.alloc('linear', 3)
    end

    private :init

    def gain=(v) @gain = v end
    def thresh=(v) @thresh = v; @interp = nil end
    def ratio=(v) @ratio = v; @interp = nil end

    def velcomp(ev)
      init unless @interp
      v = ev.vel + @gain
      v = 127 if v > 127
      v = 1   if v < 1
      v2 = @interp.eval(@x, @y, v)
      v2 = 127 if v > 127
      v2 = 1   if v < 1
      ev.vel = v2.round
    end

  end

end
