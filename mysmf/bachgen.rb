# -*- coding: utf-8 -*-
require 'tk'
require 'play_midi'

class Keyboard

  def initialize(parent=nil, unit=150)
    @w = 8
    @h = 5
    @unit_size = unit
    f_width    = @unit_size * @w
    f_height   = @unit_size * @h
    @widget = TkFrame.new(parent, 'width' => f_width, 'height' => f_height).pack
    @keys = []
    @chords = []
    @title = TkLabel.new("text" => "誰でもバッハ version 1.0", 'font' => 'Gothic 22').pack
    @title.place('x' => (f_width / 3), 'y' => 15)
    @label = TkLabel.new("text" => "オススメコードがある場合はボタンが青くなります", 'font' => "Gothic 10").pack
    @label.place('x' => (f_width / 3), 'y' => 300)
    @message = TkLabel.new("text" => "ボタンを押してコード進行を決めて下さい", 'font' => 'Gothic 12').pack
    @key_window = TkLabel.new("text" => "ここに選択したコード例が表示されます",
                              "image" => TkPhotoImage.new("file" => "image/0.gif"),
                              "compound" => "bottom").pack
    @key_window.place('x' => (f_width / 3), 'y' => 350)
    
    self
  end

  attr :widget
  attr :unit_size
  attr :keys
  attr :chords
  RECOMMEND = {
    "C" => ["D", "F", "G7", "A"],
    "D" => ["G7"],
    "F" => ["C", "D", "G7"],
    "G7" => ["C", "A"],
    "A" => ["D", "F"],
  }

  KEY_MAP = {
    "C"  => ["image/C.gif"],
    "D"  => ["image/D.gif"],
    "F"  => ["image/F.gif"],
    "G7" => ["image/G7.gif"],
    "A"  => ["image/A.gif"],
  }

  PLAYABLE = "light green"

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
      next if key.name == "PLAY"
      if recs.include?(key.name)
        color = "blue"
      else
        color = "gray"
      end
      key.set_bg(color)
    end
  end

  def replace_key_window(name = nil)
    file = KEY_MAP[name]
    file = "image/0.gif" unless file
    @key_window.image = TkPhotoImage.new("file" => file)
  end

  def play?
    if @chords.size > 3
      key = @keys.detect{|x| x.name == "PLAY"}
      key.set_bg(PLAYABLE)
    end
  end

  ### keyの色を消す
  def recommend_clear
    @keys.each do |key|
      color = "gray"
      key.set_bg(color)
    end
  end
  
  ### paly_midiへのラッパー
  def play_midi_ext																	
	recommend_clear
    chords_num = []
	chords_table={"C"=>1, "D"=>2, "F"=>4, "G7"=>5, "A"=>6}		#ちょっと無駄だが
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
    @widget.bind('Enter', proc{|e| do_mouseover x, y})
    @widget.bind('Leave', proc{|e| do_mouseout x, y})

  end
  attr :name

  def set_bg(color)
    @widget.bg = color
  end

  def moveto(x, y)
    @x = x
    @y = y
    @widget.place('x' => @unit * x + 150,
                  'y' => @unit * y,
                  'width'  => @unit * @w,
                  'height' => @unit * @h)
  end


  def do_press(x, y)
    if self.name == "PLAY"
      @board.play_midi_ext
      @board.message("演奏終了")
    else
      @board.set_chord(self.name)
      @board.recommend_next(self.name)
      @board.play?
    end
  end

  def do_release(x, y)
    if self.name == "PLAY"
     @board.message()
    else
     @board.message("現在選択しているコード進行:#{@board.chords.join("=>")}")
    end
  end

  def do_mouseover(x, y)
    @board.replace_key_window(self.name)
  end
  
  def do_mouseout(x, y)
    @board.replace_key_window()
  end
  

end

board = Keyboard.new()

# ⅢとⅦは廃止

c = Key.new(board, 'C',  2, 1, 1, 1)
d = Key.new(board, 'D',  3, 1, 1, 1)
f = Key.new(board, 'F',  4, 1, 1, 1)
g = Key.new(board, 'G7', 5, 1, 1, 1)
a = Key.new(board, 'A',  6, 1, 1, 1)
start = Key.new(board,"PLAY", 3, 2, 3, 1)
Tk.mainloop
