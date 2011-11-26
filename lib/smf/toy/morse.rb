# morse.rb: Written by Tadayoshi Funaba 2005,2006
# $Id: morse.rb,v 1.4 2006-11-10 21:58:21+09 tadf Exp $

require 'smf'
require 'smf/toy/gm'

module SMF

  class Morse

    PLAIN = {
#      '!' => 'exclamation mark',
#      '"' => 'quotation mark',
      '#' => 'number sign',
#      '$' => 'dollar sign',
      '%' => 'percent sign',
#      '&' => 'ampersand',
#      "'" => 'apostrophe',
#      '(' => 'left parenthesis',
#      ')' => 'right parenthesis',
      '*' => 'asterisk',
      '+' => 'plus sign',
#      ',' => 'comma',
#      '-' => 'hyphen', # -minus
#      '.' => 'full stop',
#      '/' => 'solidus',
#      ':' => 'colon',
#      ';' => 'semicolon',
      '<' => 'less than sign',
#      '=' => 'equals sign',
      '>' => 'greater than sign',
#      '?' => 'question mark',
#      '@' => 'commercial at',
      '[' => 'left square bracket',
      '\\' => 'reverse solidus',
      ']' => 'right square bracket',
      '^' => 'circumflex accent',
#      '_' => 'low line',
      '`' => 'grave accent',
      '{' => 'left curly bracket',
      '|' => 'vertical line',
      '}' => 'right curly bracket',
      '~' => 'tilde'
    }

    CODE = {
      ?! => '-.-.--', ?" => '.-..-.', ?$ => '...-..-',
      ?& => '. ...',  ?' => '.----.', ?( => '-.--.-', # '
      ?) => '-.--.-', ?* => '-..-',   ?+ => '.-.-.',
      ?, => '--..--', ?- => '-....-', ?. => '.-.-.-',
      ?/ => '-..-.',

      ?0 => '-----',  ?1 => '.----',  ?2 => '..---',
      ?3 => '...--',  ?4 => '....-',  ?5 => '.....',
      ?6 => '-....',  ?7 => '--...',  ?8 => '---..',
      ?9 => '----.',

      ?: => '---...', ?; => '-.-.-',  ?= => '-...-',
      ?? => '..--..', ?@ => '.--.-.',

      ?a => '.-',     ?b => '-...',   ?c => '-.-.',
      ?d => '-..',    ?e => '.',      ?f => '..-.',
      ?g => '--.',    ?h => '....',   ?i => '..',
      ?j => '.---',   ?k => '-.-',    ?l => '.-..',
      ?m => '--',     ?n => '-.',     ?o => '---',
      ?p => '.--.',   ?q => '--.-',   ?r => '.-.',
      ?s => '...',    ?t => '-',      ?u => '..-',
      ?v => '...-',   ?w => '.--',    ?x => '-..-',
      ?y => '-.--',   ?z => '--..',

      ?_ => '..--.-'
    }

    def initialize(sq, te=120)
      @sq = sq << Track.new
      @te = te
      @mesg = []
    end

    def << (s) @mesg << s end

    def plain(s)
      s = s.dup
      PLAIN.each_pair{|k, v| s.gsub!(k, ' %s ' % v)}
      s
    end

    def encode(s)
      s.downcase.scan(/\S+/).collect {|w|
	w.scan(/./).collect{|c|
	  (CODE[c[0]] || '').scan(/./).join("\s")
	}.join("\s"*3)
      }.join("\s"*7) + "\s"*15
    end

    private :plain, :encode

    def generate
      of = 0
      @sq[0] << SetTempo.new(of, 60000000 / 240)
      @sq[0] << GMSystemOn.new(of)
      of += @sq.division / 2
      @sq[0] << ProgramChange.new(of, 0, 81)
      of += @sq.division / 2
      @sq[0] << SetTempo.new(of, 60000000 / @te)
      @mesg.each do |s|
	@sq[0] << Marker.new(of, s)
	encode(plain(s)).each_byte do |c|
	  case c
	  when ?.; le = (@sq.division / 8) * 1
	  when ?-; le = (@sq.division / 8) * 3
	  else;    le = (@sq.division / 8) * 1
	  end
	  if c == ?. || c == ?-
	    @sq[0] << NoteOn .new(of,      0, 69, 96)
	    @sq[0] << NoteOff.new(of + le, 0, 69, 64)
	  end
	  of += le
	end
      end
      @sq[0] << EndOfTrack.new(of)
    end

  end

end
