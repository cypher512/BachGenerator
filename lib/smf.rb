# smf.rb: Written by Tadayoshi Funaba 1998-2006,2008
# $Id: smf.rb,v 1.39 2008-07-06 00:00:43+09 tadf Exp $

require 'smf/io'
require 'forwardable'

module SMF

  class Sequence

    def initialize(format=1, division=96, tc=nil)
      # format:0/2
      # division:1/2**15-1(if tc=nil):1/2**8-1(otherwise)
      # tc:nil,24,25,29,30
      @format, @division, @tc, @arr = format, division, tc, []
    end

    attr_accessor :format, :division, :tc

    def smpte()
      warn('smpte is deprecated; use tc') if $VERBOSE
      self.tc
    end

    def smpte=(v)
      warn('smpte= is deprecated; use tc=') if $VERBOSE
      self.tc = v
    end

    if [].respond_to?(:count)

      def ntrks() @arr.count{|x| x} end

    else

      def ntrks() @arr.nitems end

    end

    def hash() @format.hash ^ @division.hash ^ @arr.hash end
    def eql? (other) self == other end

    def == (other)
      self.class == other.class &&
	format == other.format &&
	division == other.division &&
	tc == other.tc &&
	to_a == other.to_a
    end

    def calc_set(a, b)
      sq = self.class.new(format, division, tc)
      a, b = a.to_a, b.to_a
      n = yield(a, b)
      sq.replace(n)
      sq
    end

    private :calc_set

    def + (other) calc_set(self, other){|a, b| a + b} end
    def - (other) calc_set(self, other){|a, b| a - b} end
    def & (other) calc_set(self, other){|a, b| a & b} end
    def | (other) calc_set(self, other){|a, b| a | b} end

    def * (times)
      sq = self.class.new(format, division, tc)
      sq.replace(self.to_a * times)
      sq
    end

    def << (tr)
      @arr << tr
      self
    end

    def >> (tr)
      @arr.reject!{|x| x.object_id == tr.object_id}
      self
    end

    def concat(other) replace(self + other) end

    def each
      @arr.compact.each do |tr|
	yield tr
      end
      self
    end

    def join
      sq = self.class.new(format, division, tc)
      tr = Track.new
      sq << @arr.inject(tr){|t, x| t + x}
      sq
    end

    def join!
      @arr.replace(join)
      self
    end

    def replace(another)
      if Sequence === another
	@format = another.format
	@division = another.division
	@tc = another.tc
      end
      @arr.replace(another.to_a)
      self
    end

    extend Forwardable
    include Enumerable

    de = (Array.instance_methods - self.instance_methods)
    de -= %w(assoc flatten flatten! pack rassoc transpose)
    de += %w(include? sort to_a)

    def_delegators(:@arr, *de)

    undef_method :zip

  end

  class Track

    def initialize() @arr = [] end

    if [].respond_to?(:count)

      def nevts() @arr.count{|x| x} end

    else

      def nevts() @arr.nitems end

    end

    def hash() @arr.hash end
    def eql? (other) self == other end

    def == (other)
      self.class == other.class &&
	to_a == other.to_a
    end

    def calc_set_sub(a, b, e)
      tr = self.class.new
      n = yield(a, b).reject{|x| EndOfTrack === x}
      eot = e.select{|x| EndOfTrack === x}
      n << eot.max unless eot.empty?
      tr.replace(n)
      tr
    end

    def calc_set_maxsize(a, b, &block)
      a, b = a.to_a, b.to_a
      calc_set_sub(a, b, a + b, &block)
    end

    def calc_set_selfsize(a, b, &block)
      a, b = a.to_a, b.to_a
      calc_set_sub(a, b, a, &block)
    end

    private :calc_set_sub, :calc_set_maxsize, :calc_set_selfsize

    def + (other) calc_set_maxsize(self, other){|a, b| a + b} end
    def - (other) calc_set_selfsize(self, other){|a, b| a - b} end
    def & (other) calc_set_selfsize(self, other){|a, b| a & b} end
    def | (other) calc_set_maxsize(self, other){|a, b| a | b} end

    def * (times)
      tr = self.class.new
      size = self[-1].offset
      eot, orig = partition{|x| EndOfTrack === x}
      times.times do |i|
	tr += orig.collect{|ev| ev = ev.dup; ev.offset += size * i; ev}
      end
      unless eot.empty?
	x = eot.max
	x.offset += size * times
	tr << x
      end
      tr
    end

    def << (ev)
      @arr << ev
      self
    end

    def >> (ev)
      @arr.reject!{|x| x.object_id == ev.object_id}
      self
    end

    def concat!(other) replace(self + other) end

    def each
      i = 0
      @arr.compact.sort_by{|x| [x, i += 1]}.
	each do |ev|
	yield ev
      end
      self
    end

    def _merge(a, b, &block)
      c = []
      until a.empty? || b.empty?
	c << if yield(a[0], b[0]) <= 0 then a.shift else b.shift end
      end
      c + a + b
    end

    def _sort(xs, &block)
      mid = (xs.size / 2).truncate
      if mid < 1
	xs
      else
	_merge(_sort(xs[0...mid], &block), _sort(xs[mid..-1], &block), &block)
      end
    end

    def _sort_by(xs)
      _sort(xs.collect{|x| [x, yield(x)]}){|a, b| a[1] <=> b[1]}.
	collect!{|x| x[0]}
    end

    private :_merge, :_sort, :_sort_by

    def sort(&block)
      block ||= proc{|a, b| a <=> b}
      _sort(@arr, &block)
    end

    def sort!(&block)
      replace(sort(&block))
      self
    end

    def sort_by(&block)
      _sort_by(@arr, &block)
    end

    def replace(another)
      @arr.replace(another.to_a)
      self
    end

    extend Forwardable
    include Enumerable

    de = (Array.instance_methods - self.instance_methods)
    de -= %w(assoc flatten flatten! pack rassoc transpose)
    de += %w(include? to_a)

    def_delegators(:@arr, *de)

    undef_method :zip

  end

  class Event

    include Comparable

    def initialize(offset)
      # offset:0/oo
      @offset = offset
    end

    attr_accessor :offset

    def <=>(other) self.offset <=> other.offset end

    def hash() @offset.hash end
    def eql? (other) self == other end

    def == (other)
      self.class == other.class &&
	offset == other.offset
    end

  end

  class MIDIMessage < Event; end

  class ChannelMessage < MIDIMessage

    def initialize(offset, ch)
      # ch:0/2**4-1
      super(offset)
      @ch = ch
    end

    attr_accessor :ch

    alias_method :channel, :ch
    alias_method :channel=, :ch=

    def == (other)
      super && ch == other.ch
    end

  end

  class VoiceMessage < ChannelMessage; end

  class NoteOff < VoiceMessage

    def initialize(offset, ch, note, vel)
      # note:0/2**7-1, vel:0/2**7-1
      super(offset, ch)
      @note, @vel = note, vel
    end

    attr_accessor :note

    def vel() @vel || 64 end
    def vel=(vel) @vel = vel end
    def fake?() @vel.nil? end

    alias_method :velocity, :vel
    alias_method :velocity=, :vel=

    def == (other)
      super && note == other.note && vel == other.vel
    end

  end

  class NoteOn < VoiceMessage

    def initialize(offset, ch, note, vel)
      # note:0/2**7-1, vel:0/2**7-1
      super(offset, ch)
      @note, @vel = note, vel
    end

    attr_accessor :note, :vel

    alias_method :velocity, :vel
    alias_method :velocity=, :vel=

    def == (other)
      super && note == other.note && vel == other.vel
    end

  end

  class PolyphonicKeyPressure < VoiceMessage

    def initialize(offset, ch, note, val)
      # note:0/2**7-1, val:0/2**7-1
      super(offset, ch)
      @note, @val = note, val
    end

    attr_accessor :note, :val

    alias_method :value, :val
    alias_method :value=, :val=

    def == (other)
      super && note == other.note && val == other.val
    end

  end

  class ControlChange < VoiceMessage

    def initialize(offset, ch, num, val)
      # num:0/119, val:0/2**7-1
      super(offset, ch)
      @num, @val = num, val
    end

    attr_accessor :num, :val

    alias_method :number, :num
    alias_method :number=, :num=

    alias_method :value, :val
    alias_method :value=, :val=

    def == (other)
      super && num == other.num && val == other.val
    end

  end

  class ProgramChange < VoiceMessage

    def initialize(offset, ch, num)
      # num:0/2**7-1
      super(offset, ch)
      @num = num
    end

    attr_accessor :num

    alias_method :number, :num
    alias_method :number=, :num=

    def == (other)
      super && num == other.num
    end

  end

  class ChannelPressure < VoiceMessage

    def initialize(offset, ch, val)
      # val:0/2**7-1
      super(offset, ch)
      @val = val
    end

    attr_accessor :val

    alias_method :value, :val
    alias_method :value=, :val=

    def == (other)
      super && val == other.val
    end

  end

  class PitchBendChange < VoiceMessage

    def initialize(offset, ch, val)
      # val:-2**13/2**13-1
      super(offset, ch)
      @val = val
    end

    attr_accessor :val

    alias_method :value, :val
    alias_method :value=, :val=

    def == (other)
      super && val == other.val
    end

  end

  class ChannelModeMessage < ChannelMessage; end

  [ 'AllSoundOff',
    'ResetAllControllers',
    'AllNotesOff',
    'OmniOff',
    'OmniOn',
    'PolyMode',
  ].each do |name|
    module_eval <<-"end;"
      class #{name} < ChannelModeMessage

	def initialize(offset, ch)
	  super(offset, ch)
	end

      end
    end;
  end

  [ 'LocalControl', # val:0/127
    'MonoMode',     # val:0/16
  ].each do |name|
    module_eval <<-"end;"
      class #{name} < ChannelModeMessage

	def initialize(offset, ch, val)
	  super(offset, ch)
	  @val = val
	end

	attr_accessor :val

	alias_method :value, :val
	alias_method :value=, :val=

	def == (other)
	  super && val == other.val
	end

      end
    end;
  end

  class SystemMessage < Event; end
  class ExclusiveMessage < SystemMessage; end

  class ExclusiveF0 < ExclusiveMessage

    def initialize(offset, data)
      # data.length:0/2**28-1
      super(offset)
      @data = data
    end

    attr_accessor :data

    def == (other)
      super && data == other.data
    end

  end

  class ExclusiveF7 < ExclusiveMessage

    def initialize(offset, data)
      # data.length:0/2**28-1
      super(offset)
      @data = data
    end

    attr_accessor :data

    def == (other)
      super && data == other.data
    end

  end

  class Meta < Event

    def initialize(offset)
      super(offset)
    end

  end

  class SequenceNumber < Meta

    def initialize(offset, num)
      # num:0/2**16-1
      super(offset)
      @num = num
    end

    attr_accessor :num

    alias_method :number, :num
    alias_method :number=, :num=

    def == (other)
      super && num == other.num
    end

  end

  class Text < Meta

    def initialize(offset, text)
      # text.length:0/2**28-1
      super(offset)
      @text = text
    end

    attr_accessor :text

    def == (other)
      super && text == other.text
    end

  end

  %w(GeneralPurposeText CopyrightNotice TrackName
     InstrumentName Lyric Marker CuePoint ProgramName
     DeviceName Text0A Text0B Text0C Text0D Text0E Text0F).
    each do |name|
    module_eval <<-"end;"
      class #{name} < Text

	def initialize(offset, text)
	  super(offset, text)
	end

      end
    end;
  end

  Text01 = GeneralPurposeText
  Text02 = CopyrightNotice
  SequenceName = TrackName
  Text03 = TrackName
  Text04 = InstrumentName
  Display = Lyric
  Text05 = Lyric
  Text06 = Marker
  Text07 = CuePoint
  Text08 = ProgramName
  Text09 = DeviceName

  class ChannelPrefix < Meta

    def initialize(offset, ch)
      # ch:0/2**4-1
      super(offset)
      @ch = ch
    end

    attr_accessor :ch

    alias_method :channel, :ch
    alias_method :channel=, :ch=

    def == (other)
      super && ch == other.ch
    end

  end

  class MIDIPort < Meta

    def initialize(offset, num)
      # num:0/2**8-1
      super(offset)
      @num = num
    end

    attr_accessor :num

    alias_method :number, :num
    alias_method :number=, :num=

    def == (other)
      super && num == other.num
    end

  end

  class EndOfTrack < Meta

    def initialize(offset)
      super(offset)
    end

  end

  class SetTempo < Meta

    def initialize(offset, tempo)
      # tempo:1/2**24-1
      super(offset)
      @tempo = tempo
    end

    attr_accessor :tempo

    def == (other)
      super && tempo == other.tempo
    end

  end

  class SMPTEOffset < Meta

    def initialize(offset, hr, mn, se, fr, ff, tc)
      # hr:0/23, mn:0/59, se:0/59, fr:0/29, ff:0/99, tc:24|25|29|30
      super(offset)
      @hr, @mn, @se, @fr, @ff, @tc = hr, mn, se, fr, ff, tc
    end

    attr_accessor :hr, :mn, :se, :fr, :ff, :tc

    def == (other)
      super &&
	hr == other.hr &&
	mn == other.mn &&
	se == other.se &&
	fr == other.fr &&
	ff == other.ff &&
	tc == other.tc
    end

  end

  class TimeSignature < Meta

    def initialize(offset, nn, dd, cc, bb)
      # nn,cc,bb:1/2**8-1, dd:0/2**8-1
      super(offset)
      @nn, @dd, @cc, @bb = nn, dd, cc, bb
    end

    attr_accessor :nn, :dd, :cc, :bb

    def == (other)
      super &&
	nn == other.nn &&
	dd == other.dd &&
	cc == other.cc &&
	bb == other.bb
    end

  end

  class KeySignature < Meta

    def initialize(offset, sf, mi)
      # sf:-2**7/2**7-1, mi:0/1
      super(offset)
      @sf, @mi = sf, mi
    end

    attr_accessor :sf, :mi

    def == (other)
      super && sf == other.sf && mi == other.mi
    end
  end

  class SequencerSpecific < Meta

    def initialize(offset, data)
      # data.length:0/2**28-1
      super(offset)
      @data = data
    end

    attr_accessor :data

    def == (other)
      super && data == other.data
    end

  end

end
