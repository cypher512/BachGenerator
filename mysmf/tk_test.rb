# -*- coding: utf-8 -*-
require 'tk'
require 'play_midi'

class Keyboard

  def initialize(parent=nil, unit=150)
    @w = 6
    @h = 4
    @unit_size = unit
    @widget = TkFrame.new(parent, 'width' => @unit_size * @w,
                          'height' => @unit_size *@h).pack
    @keys = []
    @chords = []
    @title = TkLabel.new("text" => "誰でもバッハ version 0.1", 'font' => 'Gothic 22').pack
    @title.place('x' => 250, 'y' => 15)
    @label = TkLabel.new("text" => "オススメコードがある場合はボタンが青くなります", 'font' => "Gothic 10").pack
    @label.place('x' => 200, 'y' => 550)
    @message = TkLabel.new("text" => "ボタンを押してコード進行を決めて下さい", 'font' => 'Gothic 12').pack
    self
  end

  attr :widget
  attr :unit_size
  attr :keys
  attr :chords
  RECOMMEND = {
    "I" => ["II", "IV", "V7", "VI"],
    "II" => ["V7"],
    "IV" => ["I", "II", "V7"],
    "V7" => ["I", "VI"],
    "VI" => ["II", "IV"],
  }

  def enter(key)
    @keys.push key
  end

  def set_chord(chord)
    @chords.push chord
  end

  def message(str="ボタンを押してコード進行を決めて下さい")
    @message.text = str
  end

  def recommend_next(key)
    recs = RECOMMEND[key]
    recs = [] unless recs
    @keys.each do |key|
      if recs.include?(key.name)
        color = "blue"
      else
        color = "gray"
      end
      key.set_bg(color)
    end
  end

  def play_midi_ext																	#paly_midiへのラッパー
    chords_num = []
	chords_table={"I"=>1, "II"=>2, "Ⅲ"=>3, "IV"=>4, "V7"=>5, "VI"=>6, "Ⅶ"=>7}		#ちょっと無駄だが置き換え
	@chords.each do |c|
		chords_num << chords_table[c]
	end	
	#pp chords_num
    play_midi chords_num
    @chords = []
  end
end

class Key
  def initialize(board, name, x, y, w= 1, h = 1)
    @name = name
    @w = w
    @h = h
    @widget = TkButton.new(board.widget,
                          'text' => name,
                          'relief' => 'raised',
                          'width' =>  5,
                          'height' =>  10,
                          'bg' => "gray")
    @board = board
    @unit = 100
    moveto(x, y)
    board.enter(self)
    @widget.bind('1', proc{|e| do_press e.x, e.y})
    @widget.bind('ButtonRelease-1', proc{|x, y| do_release x, y}, "%x %y")

  end
  attr :name

  def set_bg(color)
    @widget.bg = color
  end

  def moveto(x, y)
    @x = x
    @y = y
    @widget.place('x' => @unit * x,
                  'y' => @unit * y,
                  'width' => @unit * @w,
                  'height' => @unit * @h)
  end


  def do_press(x, y)
    if self.name == "PLAY"
      @board.play_midi_ext
      @board.message("演奏終了")
    else
      @board.set_chord(self.name)
      @board.recommend_next(self.name)
    end
  end

  def do_release(x, y)
    if self.name == "PLAY"
     @board.message()
    else
     @board.message("現在選択しているコード進行:#{@board.chords.join("=>")}")
    end
  end

end

board = Keyboard.new()

c = Key.new(board, 'I', 1, 1, 1, 1)
d = Key.new(board, 'II', 2, 1, 1, 1)
e = Key.new(board, 'III', 3, 1, 1, 1)
f = Key.new(board, 'IV',  4, 1, 1, 1)
g = Key.new(board, 'V7', 5, 1, 1, 1)
a = Key.new(board, 'VI', 6, 1, 1, 1)
b = Key.new(board, 'VII', 7, 1, 1, 1)
start = Key.new(board,"PLAY", 3, 3, 3, 1)
Tk.mainloop
