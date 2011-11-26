# -*- encoding: sjis -*-
#  �t�@�C����ǂ�ŘA��
#	@duration�𑝂₵�Ȃ���Ђ�����Ԃ��ĘA��
#	"eot"�͊O����



require "pp"
require 'midi-win'

#����
SOURCE0 = 11	#�I���S�[��
SOURCE1 = 8		#�N���r�R�[�h
SOURCE2 = 11	#�I���S�[��

def get_file(f)
#		p f				#�f�o�b�O�p�@���̓t�@�C��
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


  #attr_accessor :code		#���̍���
  
  def midi_table
    @nn = {"c"=>60, "c#"=>61, "d@"=>61, "d"=>62, "d#"=>63, "e@"=>63, "e"=>64, "f"=>65, "f#"=>66, \
    "g@"=>66, "g"=>67, "g#"=>68 , "a@"=>69, "a"=>69, "a#"=>70, "b@"=>70, "b"=>71}
    @nn_rev4 = {"c"=>"c", "d"=>"b", "e"=>"a", "f"=>"g",  "g"=>"f", "a"=>"e", "b"=>"d"}
    d = self.split()
    n = []
    k, j = 0, 0
	@duration = 0
    d.each {|i|
      if i =~ /[a-g].*/		#����
        i.scan(/([a-g][\#@]*)(.*)/) {|l|
          j = @nn[l[0]] #+ @code
          k = l[1].to_i if l[1].is_int?		#����łȂ���΍�������
          n << j + k * 12
          k = 0
        }
      elsif i.is_int?		#����
        n << "o" + i
        @duration += i.to_i
      elsif i == "//"
        n << "eot"			#�`���l���̏I���
      end
    }
    n
  end

  def midi_table_rev
    d = self.split()
    n = []
    n <<  "o720"		# �Ȃ̒��q�ɂ���ĕς��
    k, j = 0, 0
    @duration_rev = 0
    d.each {|i|
      if i =~ /[a-g].*/
        i.scan(/([a-g][\#@]*)(.*)/) {|l|
          j = @nn[@nn_rev4[l[0]]] #+ @code
          jj = @nn[l[0]]
          if l[1].is_int?
          	if (jj % 12)					#C�̏ꍇ
          		k = l[1].to_i
		        n << j - (k-1) * 12		#1����Ă���
          	else
          		k = l[1].to_i
		        n << j - k * 12			#�������]�̂�
          	end
          else
	        n << j						#�A���t�@�x�b�g�̂�
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



#####	���t�֐�	#####

### �R���@�x�[�X�����쐬
def base_table (user_in_code)
	ret = String.new
	nn = {1 => "c-1", 2 => "d-1", 4 => "f-1", 5 => "g-1", 6 => "a-1"}
	user_in_code.each_with_index do |u, i|
		ret += nn[u]
		ret += " 240 "	
		#ret += nn[u]
		ret += " 240 "
		if i + 1 < user_in_code.length				#�Ō�͂P������
			ret += nn[u]
			ret += " 240 "
		end	
	end
	ret += " //"
	return ret
end

### �e���������킹�ĉ��t����
def play_midi (user_in_code)

	#�R�[�h�i�s
	data = String.new

	user_in_code.each_with_index do |f, i|
		if i == user_in_code.length - 1					#�Ō�
			f = 0.to_s + f.to_s + "2" + ".txt"
			data += get_file(f) + " //"			
		elsif (i % 2) == 0						#�����Ԗ�
			f = 0.to_s + f.to_s + "0" + ".txt"
			data += get_file(f)
		else									#��Ԗ�
			f = 0.to_s + f.to_s + "1" + ".txt"
			data += get_file(f)
		end
	end


#	data.code = 0		#C Major

#	pp data										#�ǂݍ��񂾊y��

	cadence = data.midi_table					#�P��
	#cadence.clear
	cadence += data.midi_table_rev				#�Q���@�U���x�点�Ĕ��]
	cadence += (base_table user_in_code).midi_table

	#debug log
#	p "cadence\n"
#	p cadence									#���t���e�̃f�o�b�O�o��
	sq = Sequence.new(1,120,nil)
	ch = 0
	note = []
	velocity = 100
	offset = 0
	tr = Track.new
	tr << ProgramChange.new(0, 0, SOURCE0) << ProgramChange.new(0, 1, SOURCE1) << ProgramChange.new(0, 2, SOURCE2)
	sq << tr
	cadence.each {|c|
	  if c == "eot"			#�`���l���̏I��
	    ch += 1				#���̃`���l����p��
	    offset = 0
	    tr = Track.new
	    sq << tr
	  elsif c =~ /o\d?/		#����
	    if note != []		#�x���łȂ��ꍇ
	      o = offset
	      offset += (c.delete("o").to_i - 5)
	      note.each {|n|
	        tr << NoteOn.new(o, ch, n, velocity)
	        tr << NoteOff.new(offset, ch, n, velocity)
	      }
	      note = []
	      offset += 5
	    else				#�x���̏ꍇ
	      offset += c.delete("o").to_i
	    end
	  else					#����
	    note << c
	  end
	}
	sq.play(0)
	sq.save(File.basename("test") + ".midi")
end

#####	MAIN	#####

system("cls")

start_mes = "�ŏ��ƍŌ�� I ��  ���t�J�n��Start"
puts start_mes

ktable={121=>[60,"I ", 1], 103=>[62,"II", 2], 98=>[65,"IV", 4], 110=>[67,"V7", 5], 106=>[69,"VI", 6]}

code_table={"I "=>"II or IV or V7 or VI", "II"=>"V7", "IV"=>"I or II or V7", "V7"=>"I or VI", "VI"=>"II or IV"}

def n_on(c,n,v)
  sq = Sequence.new
  tr = Track.new
  tr << ProgramChange.new(0, 0, 11)
  sq << tr
  tr << NoteOn .new(0,0,n,v)
  tr << NoteOff .new(120,0,n,v)
  sq.play(c)
end

user_in = Array.new
user_in_code = Array.new


c = Win32API.new('msvcrt','_getch',[],'l')
while true
  k = c.call
 
 
  
  n_on(0, ktable[k][0], 127) if ktable.key?(k)
  if k == 27											#�u���O�����I��
  	break
  end
  if ktable.key?(k)
  	puts ktable[k][1] + "  ���̃R�[�h��� => " + code_table[ktable[k][1]]
	user_in << ktable[k][1]
	user_in_code << ktable[k][2]
  end
  if k == 104	#'h'�L�[
  	puts "���Ȃ��̃R�[�h�i�s"
  	p user_in
  	play_midi user_in_code								#���t�J�n

  	user_in.clear; user_in_code.clear
  	puts "���t�I���I�I"
  	sleep 2
  	system("cls")
	puts start_mes
  end	
end


