# text.rb: Written by Tadayoshi Funaba 1999-2006
# $Id: text.rb,v 1.4 2006-11-10 21:58:21+09 tadf Exp $

module SMF

  class Sequence

    class RSText

      class PO

	def initialize(str)
	  @arr = str.split(/\n+/).
	    collect{|x| x.strip}.
	    select{|x| !x.empty?}
	end

	def gets() @arr.shift end
	def eof?() @arr.empty? end

      end

      def initialize(s, cb) @s, @cb = s, cb end

      def get_offset(s)
	s.sub!(/\A\s*(\d+)/, '')
	return $1.to_i
      end

      def get_name(s)
	s.sub!(/\A\s*(\S+)/, '')
	return $1
      end

      def get_params(s)
	s.scan(/\d+/).collect{|x| x.to_i}
      end

      def get_text(s)
	eval(s)
      end

      private :get_offset, :get_name, :get_params, :get_text

      def read_header(rs)
	ln = rs.gets
	name = get_name(ln)
	case name
	when /\AMThd/i
	  f, n, d, s = get_params(ln)
	  @cb.header(f, n, d, s)
	else
	  @cb.error('not a text')
	end
      end

      def read_track(rs)
	ln = rs.gets
	case ln
	when /\AMTrk\z/i
	  @cb.track_start
	else
	  @cb.error('track not found')
	end
	loffset = 0
	until rs.eof?
	  ln = rs.gets
	  case ln
	  when /\AMTrkEnd\z/i
	    @cb.track_end
	    return
	  end
	  offset = get_offset(ln)
	  @cb.delta(offset - loffset)
	  loffset = offset
	  name = get_name(ln)
	  case name
	  when /\ANoteOff\z/i
	    @cb.noteoff(*get_params(ln)[0,3])
	  when /\ANoteOn\z/i
	    @cb.noteon(*get_params(ln)[0,3])
	  when /\APolyphonicKeyPressure\z/i
	    @cb.polyphonickeypressure(*get_params(ln)[0,3])
	  when /\AControlChange\z/i
	    @cb.controlchange(*get_params(ln)[0,3])
	  when /\AProgramChange\z/i
	    @cb.programchange(*get_params(ln)[0,2])
	  when /\AChannelPressure\z/i
	    @cb.channelpressure(*get_params(ln)[0,2])
	  when /\APitchBendChange\z/i
	    @cb.pitchbendchange(*get_params(ln)[0,2])
	  when /\AAllSoundOff\z/i
	    ch, = get_params(ln)
	    @cb.allsoundoff(ch)
	  when /\AResetAllControllers\z/i
	    ch, = get_params(ln)
	    @cb.resetallcontrollers(ch)
	  when /\ALocalControl\z/i
	    ch, val, = get_params(ln)
	    @cb.localcontrol(ch, val)
	  when /\AAllNotesOff\z/i
	    ch, = get_params(ln)
	    @cb.allnotesoff(ch)
	  when /\AOmniOff\z/i
	    ch, = get_params(ln)
	    @cb.omnioff(ch)
	  when /\AOmniOn\z/i
	    ch, = get_params(ln)
	    @cb.omnion(ch)
	  when /\AMonoMode\z/i
	    ch, val, = get_params(ln)
	    @cb.monomode(ch, val)
	  when /\APolyMode\z/i
	    ch, = get_params(ln)
	    @cb.polymode(ch)
	  when /\AExclusiveF0\z/i
	    @cb.exclusivef0(get_text(ln))
	  when /\AExclusiveF7\z/i
	    @cb.exclusivef7(get_text(ln))
	  when /\ASequenceNumber\z/i
	    @cb.sequencenumber(*get_params(ln)[0,1])
	  when /\A(GeneralPurposeText|Text01)\z/i
	    @cb.generalpurposetext(get_text(ln))
	  when /\A(CopyrightNotice|Text02)\z/i
	    @cb.copyrightnotice(get_text(ln))
	  when /\A(TrackName|SequenceName|Text03)\z/i
	    @cb.trackname(get_text(ln))
	  when /\A(InstrumentName|Text04)\z/i
	    @cb.instrumentname(get_text(ln))
	  when /\A(Lyric|Text05)\z/i
	    @cb.lyric(get_text(ln))
	  when /\A(Marker|Text06)\z/i
	    @cb.marker(get_text(ln))
	  when /\A(CuePoint|Text07)\z/i
	    @cb.cuepoint(get_text(ln))
	  when /\A(ProgramName|Text08)\z/i
	    @cb.programname(get_text(ln))
	  when /\A(DeviceName|Text09)\z/i
	    @cb.devicename(get_text(ln))
	  when /\AText0([A-F])\z/i
	    case $1
	    when 'A'; @cb.text0a(get_text(ln))
	    when 'B'; @cb.text0b(get_text(ln))
	    when 'C'; @cb.text0c(get_text(ln))
	    when 'D'; @cb.text0d(get_text(ln))
	    when 'E'; @cb.text0e(get_text(ln))
	    when 'F'; @cb.text0f(get_text(ln))
	    end
	  when /\AChannelPrefix\z/i
	    @cb.channelprefix(*get_params(ln)[0,1])
	  when /\AMIDIPort\z/i
	    @cb.midiport(*get_params(ln)[0,1])
	  when /\AEndOfTrack\z/i
	    @cb.endoftrack()
	  when /\ASetTempo\z/i
	    @cb.settempo(*get_params(ln)[0,1])
	  when /\ASMPTEOffset\z/i
	    @cb.smpteoffset(*get_params(ln)[0,6])
	  when /\ATimeSignature\z/i
	    @cb.timesignature(*get_params(ln)[0,4])
	  when /\AKeySignature\z/i
	    @cb.keysignature(*get_params(ln)[0,2])
	  when /\ASequencerSpecific\z/i
	    @cb.sequencerspecific(get_text(ln))
	  else
	    @cb.error('unknown event: ' + name)
	  end
	end
	@cb.track_end
      end

      private :read_header, :read_track

      def read
	rs = RSText::PO.new(@s)
	read_header(rs)
	until rs.eof?
	  read_track(rs)
	end
	@cb.result
      end

    end

    class << self

      def decode_text(s)
	self::RSText.new(s, self::Decode.new).read
      end

      def read_text(io)
	decode_text(io.binmode.read)
      end

      def load_text(fn)
	open(fn) do |io|
	  read_text(io)
	end
      end

    end

    class EncodeText < XSCallback

      def header(format, ntrks, division, tc)
	if tc
	  @s = format("MThd %d %d %d %d\n", format, ntrks, division, tc)
	else
	  @s = format("MThd %d %d %d\n", format, ntrks, division)
	end
      end

      def track_start() @offset = 0; @s << "MTrk\n" end
      def track_end()   @offset = 0; @s << "MTrkEnd\n" end

      def delta(delta) @offset += delta end

      def noteoff(ch, note, vel)
	@s << format("%d NoteOff %d %d %d\n", @offset, ch, note, vel)
      end

      def noteon(ch, note, vel)
	@s << format("%d NoteOn %d %d %d\n", @offset, ch, note, vel)
      end

      def polyphonickeypressure(ch, note, val)
	@s << format("%d PolyphonicKeyPressure %d %d %d\n",
		     @offset, ch, note, val)
      end

      def controlchange(ch, num, val)
	@s << format("%d ControlChange %d %d %d\n", @offset, ch, num, val)
      end

      def programchange(ch, num)
	@s << format("%d ProgramChange %d %d\n", @offset, ch, num)
      end

      def channelpressure(ch, val)
	@s << format("%d ChannelPressure %d %d\n", @offset, ch, val)
      end

      def pitchbendchange(ch, val)
	@s << format("%d PitchBendChange %d %d\n", @offset, ch, val)
      end

      def allsoundoff(ch)
	@s << format("%d AllSoundOff %d\n", @offset, ch)
      end

      def resetallcontrollers(ch)
	@s << format("%d ResetAllControllers %d\n", @offset, ch)
      end

      def localcontrol(ch, val)
	@s << format("%d LocalControl %d %d\n", @offset, ch, val)
      end

      def allnotesoff(ch)
	@s << format("%d AllNotesOff %d\n", @offset, ch)
      end

      def omnioff(ch)
	@s << format("%d OmniOff %d\n", @offset, ch)
      end

      def omnion(ch)
	@s << format("%d OmniOn %d\n", @offset, ch)
      end

      def monomode(ch, val)
	@s << format("%d MonoMode %d %d\n", @offset, ch, val)
      end

      def polymode(ch)
	@s << format("%d PolyMode %d\n", @offset, ch)
      end

      def put_binary(name, data)
	@s << format('%d %s "', @offset, name)
	data.each_byte do |c|
	  @s << format('\\%03o', c)
	end
	@s << "\"\n" # "
      end

      private :put_binary

      def exclusivef0(data) put_binary('ExclusiveF0', data) end
      def exclusivef7(data) put_binary('ExclusiveF7', data) end

      def sequencenumber(num)
	@s << format("%d SequenceNumber %d\n", @offset, num)
      end

      def text(name, text)
	@s << format("%d %s %s\n", @offset, name, text.dump)
      end

      private :text

      def generalpurposetext(text) text('GeneralPurposeText', text) end
      def copyrightnotice(text) text('CopyrightNotice', text) end
      def trackname(text) text('TrackName', text) end
      def instrumentname(text) text('InstrumentName', text) end
      def lyric(text) text('Lyric', text) end
      def marker(text) text('Marker', text) end
      def cuepoint(text) text('CuePoint', text) end
      def programname(text) text('ProgramName', text) end
      def devicename(text) text('DeviceName', text) end
      def text0a(text) text('Text0A', text) end
      def text0b(text) text('Text0B', text) end
      def text0c(text) text('Text0C', text) end
      def text0d(text) text('Text0D', text) end
      def text0e(text) text('Text0E', text) end
      def text0f(text) text('Text0F', text) end

      def channelprefix(ch)
	@s << format("%d ChannelPrefix %d\n", @offset, ch)
      end

      def midiport(num)
	@s << format("%d MIDIPort %d\n", @offset, num)
      end

      def endoftrack
	@s << format("%d EndOfTrack\n", @offset)
      end

      def settempo(tempo)
	@s << format("%d SetTempo %d\n", @offset, tempo)
      end

      def smpteoffset(hr, mn, se, fr, ff, tc)
	@s << format("%d SMPTEOffset %d %d %d %d %d %d\n",
		     @offset, hr, mn, se, fr, ff, tc)
      end

      def timesignature(nn, dd, cc, bb)
	@s << format("%d TimeSignature %d %d %d %d\n", @offset, nn, dd, cc, bb)
      end

      def keysignature(sf, mi)
	@s << format("%d KeySignature %d %d\n", @offset, sf, mi)
      end

      def sequencerspecific(data) put_binary('SequencerSpecific', data) end

      def result() @s end

    end

    def encode_text
      self.class::WS.new(self, self.class::EncodeText.new).read
    end

    def write_text(io)
      io.write(encode_text)
    end

    def save_text(fn)
      open(fn, 'w') do |io|
	write_text(io)
      end
    end

  end

end
