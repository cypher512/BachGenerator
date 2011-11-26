# virtual.rb: Written by Tadayoshi Funaba 2005,2006
# $Id: virtual.rb,v 1.3 2006-11-10 21:58:21+09 tadf Exp $

module SMF

  class Sequence

    def to_virtual
      v = VirtualSequence.new(format, division, tc)
      each do |tr|
	v << tr.to_virtual
      end
      v
    end

  end

  class Track

    def to_virtual
      v = VirtualTrack.new
      xs = []
      each do |ev|
	case ev
	when NoteOn
	  xs.push(ev)
	when NoteOff
	  on = nil
	  i = 0
	  xs.each_with_index do |x, i|
	    if x.ch == ev.ch && x.note == ev.note
	      on = x
	      break
	    end
	  end
	  if on
	    v << VirtualNote.new(on.offset, on.ch, on.note,
				 on.vel, ev.vel, ev.offset - on.offset)
	    xs.delete_at(i)
	  end
	else
	  v << ev
	end
      end
      v
    end

  end

end

module SMF

  class VirtualSequence < Sequence

    class RS < Sequence::RS; end
    class WS < Sequence::WS

      def initialize(o, cb) super(o.to_real, cb) end

    end

    class Decode < Sequence::Decode

      def result() super().to_virtual end

    end

    class Encode < Sequence::Encode; end

    def initialize(format, division, tc)
      super(format, division, tc)
    end

    def to_real
      r = Sequence.new(format, division, tc)
      each do |tr|
	r << tr.to_real
      end
      r
    end

  end

  class VirtualTrack < Track

    def initialize()
      super()
    end

    def to_real
      r = Track.new
      each do |ev|
	case ev
	when VirtualNote
	  r << NoteOn.new(ev.offset, ev.ch, ev.note, ev.vel)
	  r << NoteOff.new(ev.offset + ev.length, ev.ch, ev.note, ev.offvel)
	else
	  r << ev
	end
      end
      r
    end

  end

  class VirtualNote < VoiceMessage

    def initialize(offset, ch, note, vel, offvel, length)
      super(offset, ch)
      @note, @vel, @offvel, @length = note, vel, offvel, length
    end

    attr_accessor :note, :vel, :offvel, :length

  end

end
