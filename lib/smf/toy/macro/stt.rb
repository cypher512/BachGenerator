# stt.rb: Written by Tadayoshi Funaba 2005
# $Id: stt.rb,v 1.2 2005-07-17 17:08:20+09 tadf Exp $

$KCODE = 'e'

require 'smf/toy/macro/mml'
require 'kconv'
require 'jcode'

module SMF

  class STT < MML

    NOTETAB = { 'ラ'=>'a', 'シ'  =>'b', 'ド'=>'c', 'レ'=>'d',
		'ミ'=>'e', 'ファ'=>'f', 'ソ'=>'g', 'ッ'=>'r' }

    def << (s)
      s2 = s.toeuc.
	gsub(/(ラ|シ|ド|レ|ミ|ファ|ソ|ッ)([$%#♭％＃]+)?([,'，’]+)?(ー+)?/) do
	n, s, o, x = $1, $2, $3, $4
	no = NOTETAB[n]
	no += s.tr('♭％＃', '$%#') if s
	no += o.tr('，’', ",'") if o
	le = 1
	le += x.jsize if x
	format('{le*=%d %s}', le, no)
      end
      super(s2)
    end

  end

end
