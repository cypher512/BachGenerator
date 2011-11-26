# mml.rb: Written by Tadayoshi Funaba 2005
# $Id: mml.rb,v 1.1 2005-07-17 17:08:20+09 tadf Exp $

require 'smf/toy/macro/mml/parser'

module SMF

  class MML

    def initialize(sq)
      @sq = sq << Track.new
      @list = []
    end

    def << (s) @list << s << "\n" end

    def generate
      so = @list.join
      sh = Sheet.new(@sq)
      de = Descripter.new(sh)
      pa = MMLParser.new
      ev = MMLEvaluator.new(de)
      begin
	st = pa.parse(so)
	ev.evaluate(st)
	sh.generate
      rescue ParseError
	raise ParseError, format('%d: syntax error', pa.lineno)
      end
    end

  end

end
