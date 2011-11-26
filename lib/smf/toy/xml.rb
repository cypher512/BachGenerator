# xml.rb: Written by Tadayoshi Funaba 2004-2007
# $Id: xml.rb,v 1.4 2007-12-26 20:33:25+09 tadf Exp $

require 'rexml/document'
require 'rexml/streamlistener'

begin require 'rexml/formatters/pretty'; rescue LoadError; end

module SMF

  class Sequence

    class RSXML

      def initialize(s, cb) @s, @cb = s, cb end

      include REXML::StreamListener

      def get_params(attrs, keys)
	attrs.values_at(*keys).collect{|x| x.to_i}
      end

      def get_text(attrs, key)
	s = attrs[key]
	eval('"%s"' % s)
      end

      def tag_start(name, attrs)
	if attrs['offset']
	  offset = attrs['offset'].to_i
	  @cb.delta(offset - @loffset)
	  @loffset = offset
	end
	case name
	when /\AMThd\z/i
	  f, n, d, s = get_params(attrs, %w(format ntrks division tc))
	  s = nil if attrs['tc']
	  @cb.header(f, n, d, s)
	when /\AMTrk\z/i
	  @loffset = 0
	  @cb.track_start
	when /\ANoteOff\z/i
	  @cb.noteoff(*get_params(attrs, %w(ch note vel)))
	when /\ANoteOn\z/i
	  @cb.noteon(*get_params(attrs, %w(ch note vel)))
	when /\APolyphonicKeyPressure\z/i
	  @cb.polyphonickeypressure(*get_params(attrs, %w(ch note val)))
	when /\AControlChange\z/i
	  @cb.controlchange(*get_params(attrs, %w(ch num val)))
	when /\AProgramChange\z/i
	  @cb.programchange(*get_params(attrs, %w(ch num)))
	when /\AChannelPressure\z/i
	  @cb.channelpressure(*get_params(attrs, %w(ch val)))
	when /\APitchBendChange\z/i
	  @cb.pitchbendchange(*get_params(attrs, %w(ch val)))
	when /\AAllSoundOff\z/i
	  ch, = get_params(attrs, %w(ch))
	  @cb.allsoundoff(ch)
	when /\AResetAllControllers\z/i
	  ch, = get_params(attrs, %w(ch))
	  @cb.resetallcontrollers(ch)
	when /\ALocalControl\z/i
	  ch, val, = get_params(attrs, %w(ch, val))
	  @cb.localcontrol(ch, val)
	when /\AAllNotesOff\z/i
	  ch, = get_params(attrs, %w(ch))
	  @cb.allnotesoff(ch)
	when /\AOmniOff\z/i
	  ch, = get_params(attrs, %w(ch))
	  @cb.omnioff(ch)
	when /\AOmniOn\z/i
	  ch, = get_params(attrs, %w(ch))
	  @cb.omnion(ch)
	when /\AMonoMode\z/i
	  ch, val, = get_params(attrs, %w(ch val))
	  @cb.monomode(ch, val)
	when /\APolyMode\z/i
	  ch, = get_params(attrs, %w(ch))
	  @cb.polymode(ch)
	when /\AExclusiveF0\z/i
	  @cb.exclusivef0(get_text(attrs, 'data'))
	when /\AExclusiveF7\z/i
	  @cb.exclusivef7(get_text(attrs, 'data'))
	when /\ASequenceNumber\z/i
	  @cb.sequencenumber(*get_params(attrs, %w(num)))
	when /\A(GeneralPurposeText|Text01)\z/i
	  @cb.generalpurposetext(get_text(attrs, 'text'))
	when /\A(CopyrightNotice|Text02)\z/i
	  @cb.copyrightnotice(get_text(attrs, 'text'))
	when /\A(TrackName|SequenceName|Text03)\z/i
	  @cb.trackname(get_text(attrs, 'text'))
	when /\A(InstrumentName|Text04)\z/i
	  @cb.instrumentname(get_text(attrs, 'text'))
	when /\A(Lyric|Text05)\z/i
	  @cb.lyric(get_text(attrs, 'text'))
	when /\A(Marker|Text06)\z/i
	  @cb.marker(get_text(attrs, 'text'))
	when /\A(CuePoint|Text07)\z/i
	  @cb.cuepoint(get_text(attrs, 'text'))
	when /\A(ProgramName|Text08)\z/i
	  @cb.programname(get_text(attrs, 'text'))
	when /\A(DeviceName|Text09)\z/i
	  @cb.devicename(get_text(attrs, 'text'))
	when /\AText0([A-F])\z/i
	  case $1
	  when 'A'; @cb.text0a(get_text(attrs, 'text'))
	  when 'B'; @cb.text0b(get_text(attrs, 'text'))
	  when 'C'; @cb.text0c(get_text(attrs, 'text'))
	  when 'D'; @cb.text0d(get_text(attrs, 'text'))
	  when 'E'; @cb.text0e(get_text(attrs, 'text'))
	  when 'F'; @cb.text0f(get_text(attrs, 'text'))
	  end
	when /\AChannelPrefix\z/i
	  @cb.channelprefix(*get_params(attrs, %w(ch)))
	when /\AMIDIPort\z/i
	  @cb.midiport(*get_params(attrs, %w(num)))
	when /\AEndOfTrack\z/i
	  @cb.endoftrack()
	when /\ASetTempo\z/i
	  @cb.settempo(*get_params(attrs, %w(tempo)))
	when /\ASMPTEOffset\z/i
	  @cb.smpteoffset(*get_params(attrs, %w(hr mn se fr ff tc)))
	when /\ATimeSignature\z/i
	  @cb.timesignature(*get_params(attrs, %w(nn dd cc bb)))
	when /\AKeySignature\z/i
	  @cb.keysignature(*get_params(attrs, %w(sf mi)))
	when /\ASequencerSpecific\z/i
	  @cb.sequencerspecific(get_text(attrs, 'data'))
	else
	  @cb.error('unknown event: ' + name)
	end
      end

      def read
	REXML::Document.parse_stream(@s, self)
	@cb.result
      end

    end

    class << self

      def decode_xml(s)
	self::RSXML.new(s, self::Decode.new).read
      end

      def read_xml(io)
	decode_xml(io.binmode.read)
      end

      def load_xml(fn)
	open(fn) do |io|
	  read_xml(io)
	end
      end

    end

    class EncodeXML < XSCallback

      def header(format, ntrks, division, tc)
	@doc = REXML::Document.new
	@doc << REXML::XMLDecl.new
	@docsq = REXML::Element.new('MThd', @doc)
	@docsq.attributes['format'] = format.to_s
	@docsq.attributes['division'] = division.to_s
	@docsq.attributes['tc'] = tc.to_s
      end

      def track_start()
	@offset = 0
	@doctr = REXML::Element.new('MTrk', @docsq)
      end

      def delta(delta) @offset += delta end

      def noteoff(ch, note, vel)
	e = REXML::Element.new('NoteOff', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['note'] = note.to_s
	e.attributes['vel'] = vel.to_s
      end

      def noteon(ch, note, vel)
	e = REXML::Element.new('NoteOn', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['note'] = note.to_s
	e.attributes['vel'] = vel.to_s
      end

      def polyphonickeypressure(ch, note, val)
	e = REXML::Element.new('PolyphonicKeyPressure', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['note'] = note.to_s
	e.attributes['val'] = val.to_s
      end

      def controlchange(ch, num, val)
	e = REXML::Element.new('ControlChange', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['num'] = num.to_s
	e.attributes['val'] = val.to_s
      end

      def programchange(ch, num)
	e = REXML::Element.new('ProgramChange', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['num'] = num.to_s
      end

      def channelpressure(ch, val)
	e = REXML::Element.new('ChannelPressure', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['val'] = val.to_s
      end

      def pitchbendchange(ch, val)
	e = REXML::Element.new('PitchBendChange', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['val'] = val.to_s
      end

      def channelmodemessage(name, ch, val=nil)
	e = REXML::Element.new(name, @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
	e.attributes['val'] = val.to_s if val
      end

      private :channelmodemessage

      def allsoundoff(ch) channelmodemessage('AllSoundOff', ch) end
      def resetallcontrollers(ch) channelmodemessage('ResetAllControllers', ch) end
      def localcontrol(ch, val) channelmodemessage('LocalControl', ch, val) end
      def allnotesoff(ch) channelmodemessage('AllNotesOff', ch) end
      def omnioff(ch) channelmodemessage('OmniOff', ch) end
      def omnion(ch) channelmodemessage('OmniOn', ch) end
      def monomode(ch, val) channelmodemessage('MonoMode', ch, val) end
      def polymode(ch) channelmodemessage('PolyMode', ch) end

      def put_binary(name, data)
	e = REXML::Element.new(name, @doctr)
	e.attributes['offset'] = @offset.to_s
	s = ''
	data.each_byte do |c|
	  s << format('\\%03o', c)
	end
	e.attributes['data'] = s
      end

      private :put_binary

      def exclusivef0(data) put_binary('ExclusiveF0', data) end
      def exclusivef7(data) put_binary('ExclusiveF7', data) end

      def sequencenumber(num)
	e = REXML::Element.new('SequenceNumber', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['num'] = num.to_s
      end

      def text(name, text)
	e = REXML::Element.new(name, @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['text'] = text.dump[1..-2]
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
	e = REXML::Element.new('ChannelPrefix', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['ch'] = ch.to_s
      end

      def midiport(num)
	e = REXML::Element.new('MIDIPort', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['num'] = num.to_s
      end

      def endoftrack
	e = REXML::Element.new('EndOfTrack', @doctr)
	e.attributes['offset'] = @offset.to_s
      end

      def settempo(tempo)
	e = REXML::Element.new('SetTempo', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['tempo'] = tempo.to_s
      end

      def smpteoffset(hr, mn, se, fr, ff, tc)
	e = REXML::Element.new('SMPTEOffset', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['hr'] = hr.to_s
	e.attributes['mn'] = mn.to_s
	e.attributes['se'] = se.to_s
	e.attributes['fr'] = fr.to_s
	e.attributes['ff'] = ff.to_s
	e.attributes['tc'] = tc.to_s
      end

      def timesignature(nn, dd, cc, bb)
	e = REXML::Element.new('TimeSignature', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['nn'] = nn.to_s
	e.attributes['dd'] = dd.to_s
	e.attributes['cc'] = cc.to_s
	e.attributes['bb'] = bb.to_s
      end

      def keysignature(sf, mi)
	e = REXML::Element.new('KeySignature', @doctr)
	e.attributes['offset'] = @offset.to_s
	e.attributes['sf'] = sf.to_s
	e.attributes['mi'] = mi.to_s
      end

      def sequencerspecific(data) put_binary('SequencerSpecific', data) end

      unless defined? REXML::Formatters::Pretty

	def result() @doc.to_s(0) end

      else

	def result
	  f = REXML::Formatters::Pretty.new(2)
	  f.write(@doc, r = "")
	  r
	end

      end

    end

    def encode_xml
      self.class::WS.new(self, self.class::EncodeXML.new).read
    end

    def write_xml(io)
      io.write(encode_xml)
    end

    def save_xml(fn)
      open(fn, 'w') do |io|
	write_xml(io)
      end
    end

  end

end
