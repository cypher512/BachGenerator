# -*- encoding: utf-8 -*-
#  ファイルを読んで連結
#	@durationを増やしながらひっくり返して連結
#	"eot"は外から




require "pp"
require 'midi-win'
require 'fileutils'
include FileUtils
include FileTest

#音源
SOURCE0 = 11	#オルゴール
SOURCE1 = 8		#クラビコード
SOURCE2 = 11	#オルゴール

def get_file(f)
#		p f				#デバッグ用　入力ファイル
	open(f) do |io|
		d = ""
		while line = io.gets
			d += line
			
		end
		d
	end	
end


class String
  def is_int?
    return self == self.to_i.to_s
  end


  #attr_accessor :code		#調の高さ
  
  def midi_table
    @nn = {"c"=>60, "c#"=>61, "d@"=>61, "d"=>62, "d#"=>63, "e@"=>63, "e"=>64, "f"=>65, "f#"=>66, \
    "g@"=>66, "g"=>67, "g#"=>68 , "a@"=>69, "a"=>69, "a#"=>70, "b@"=>70, "b"=>71}
    @nn_rev4 = {"c"=>"c", "d"=>"b", "e"=>"a", "f"=>"g",  "g"=>"f", "a"=>"e", "b"=>"d"}
    d = self.split()
    n = []
    k, j = 0, 0
	@duration = 0
    d.each {|i|
      if i =~ /[a-g].*/		#高さ
        i.scan(/([a-g][\#@]*)(.*)/) {|l|
          j = @nn[l[0]] #+ @code
          k = l[1].to_i if l[1].is_int?		#無印でなければ高さ調整
          n << j + k * 12
          k = 0
        }
      elsif i.is_int?		#長さ
        n << "o" + i
        @duration += i.to_i
      elsif i == "//"
        n << "eot"			#チャネルの終わり
      end
    }
    n
  end

  def midi_table_rev
    d = self.split()
    n = []
    n <<  "o720"		# 曲の調子によって変わる
    k, j = 0, 0
    @duration_rev = 0
    d.each {|i|
      if i =~ /[a-g].*/
        i.scan(/([a-g][\#@]*)(.*)/) {|l|
          j = @nn[@nn_rev4[l[0]]] #+ @code
          jj = @nn[l[0]]
          if l[1].is_int?
          	if (jj % 12)					#Cの場合
          		k = l[1].to_i
		        n << j - (k-1) * 12		#1ずれている
          	else
          		k = l[1].to_i
		        n << j - k * 12			#符号反転のみ
          	end
          else
	        n << j						#アルファベットのみ
          end
       }
      elsif i.is_int?
        n << "o" + i
        @duration_rev += i.to_i
        if @duration_rev + 480 + 480 >= @duration
       		n << "eot"; return n
        end
      elsif i == "//"
        n << "eot"
      end
    }
    n
  end  
end



#####	演奏関数	#####

### ３声　ベース音を作成
def base_table (user_in_code)
	ret = String.new
	nn = {1 => "c-1", 2 => "d-1", 4 => "f-1", 5 => "g-1", 6 => "a-1"}
	user_in_code.each_with_index do |u, i|
		ret += nn[u]
		ret += " 240 "	
		#ret += nn[u]
		ret += " 240 "
		if i + 1 < user_in_code.length				#最後は１音だけ
			ret += nn[u]
			ret += " 240 "
		end	
	end
	ret += " // "
	return ret
end

### 各声部を合わせて演奏する
def play_midi (user_in_code)

	#コード進行
	data = String.new
#	pp user_in_code
	user_in_code.each_with_index do |f, i|
		if i == user_in_code.length - 1					#最後
			ff = 0.to_s + f.to_s + "2" + ".txt"
#			pp ff ;pp "0"
			data += get_file(ff) + " // "			
		elsif i == 0 && f == 0									#最初
			ff = rand(4).to_s + f.to_s + "0" + ".txt"
#			pp ff ;pp "1"
			data += get_file(ff)		
		elsif (i % 2) == 0						#偶数番目
			ff = rand(2).to_s + f.to_s + "0" + ".txt"
#			pp ff ;pp "2"
			data += get_file(ff)
		else									#奇数番目
			ff = rand(2).to_s + f.to_s + "1" + ".txt"
#			pp ff ;pp "3"
			data += get_file(ff)
		end
	end


#	data.code = 0		#C Major

#	pp data										#読み込んだ楽譜

	cadence = data.midi_table					#１声
	#cadence.clear
	cadence += data.midi_table_rev				#２声　６拍遅らせて反転
	cadence += (base_table user_in_code).midi_table

	#debug log
#	p "cadence\n"
#	p cadence									#演奏内容のデバッグ出力
	sq = Sequence.new(1,120,nil)
	ch = 0
	note = []
	velocity = 100
	offset = 0
	tr = Track.new
	tr << ProgramChange.new(0, 0, SOURCE0) << ProgramChange.new(0, 1, SOURCE1) << ProgramChange.new(0, 2, SOURCE2)
	sq << tr
	cadence.each {|c|
	  if c == "eot"			#チャネルの終り
	    ch += 1				#次のチャネルを用意
	    offset = 0
	    tr = Track.new
	    sq << tr
	  elsif c =~ /o\d?/		#長さ
	    if note != []		#休息でない場合
	      o = offset
	      offset += (c.delete("o").to_i - 5)
	      note.each {|n|
	        tr << NoteOn.new(o, ch, n, velocity)
	        tr << NoteOff.new(offset, ch, n, velocity)
	      }
	      note = []
	      offset += 5
	    else				#休息の場合
	      offset += c.delete("o").to_i
	    end
	  else					#高さ
	    note << c
	  end
	}
	sq.play(0)															#演奏
	sq.save(File.basename("test") + ".midi")							#ファイルに落とす
	
	if not directory?("archive")										#archiveディレクトリなかったら作る
		mkdir("archive")
	end	
	to = "archive/" + Time.now.strftime("%Y_%m%d_%H%M_%S") + ".midi"	#退避
	cp("test.midi", to)
end



