# io.rb: Written by Tadayoshi Funaba 1998-2008
# $Id: io.rb,v 1.9 2008-11-12 19:24:09+09 tadf Exp $

module SMF

  class Sequence

    class ReadError < StandardError; end

    class RS

      class PO

	def self.u2s(u, w) u -= 2**w if u > 2**(w-1)-1; u end

	def initialize(str) @str, @index = str, 0 end
	def rem() @str.length - @index end
	def eof? () rem <= 0 end
	def skip(n) @index += n end

	def getn(n)
	  raise EOFError if rem < n
	  s = @str[@index, n]
	  skip(n)
	  s
	end

	unless String === '0'[0]

	  def getc
	    raise EOFError if rem < 1
	    c = @str[@index]
	    skip(1)
	    c
	  end

	else

	  def getc
	    raise EOFError if rem < 1
	    c = @str[@index].ord
	    skip(1)
	    c
	  end

	end

	def getl
	  v = 0
	  begin
	    v <<= 7
	    c = getc
	    v |= c & 0x7f
	  end until (c & 0x80).zero?
	  v
	end

	def geti(n)
	  u = 0
	  n.times do
	    u <<= 8
	    c = getc
	    u |= c
	  end
	  u
	end

	def geti16() geti(2) end
	def geti24() geti(3) end
	def geti32() geti(4) end

	def to_s() @str.dup end

      end

      def initialize(s, cb) @s, @cb = s, cb end

      def read_header(s)
	rs = RS::PO.new(s)
	format = rs.geti16
	ntrks = rs.geti16
	div1 = rs.getc
	div2 = rs.getc
	if (div1 & 0x80) == 0
	  tc = nil
	  division = div1 << 8 | div2
	else
	  tc = 0x100 - div1
	  division = div2
	end
	@cb.header(format, ntrks, division, tc)
      end

      def read_meta(type, data)
	case type
	when 0x0
	  rs = RS::PO.new(data)
	  num = rs.geti16
	  @cb.sequencenumber(num)
	when 0x1..0xf
	  case type
	  when 0x1; @cb.generalpurposetext(data)
	  when 0x2; @cb.copyrightnotice(data)
	  when 0x3; @cb.trackname(data)
	  when 0x4; @cb.instrumentname(data)
	  when 0x5; @cb.lyric(data)
	  when 0x6; @cb.marker(data)
	  when 0x7; @cb.cuepoint(data)
	  when 0x8; @cb.programname(data)
	  when 0x9; @cb.devicename(data)
	  when 0xa; @cb.text0a(data)
	  when 0xb; @cb.text0b(data)
	  when 0xc; @cb.text0c(data)
	  when 0xd; @cb.text0d(data)
	  when 0xe; @cb.text0e(data)
	  when 0xf; @cb.text0f(data)
	  end
	when 0x20
	  rs = RS::PO.new(data)
	  ch = rs.getc
	  @cb.channelprefix(ch)
	when 0x21
	  rs = RS::PO.new(data)
	  num = rs.getc
	  @cb.midiport(num)
	when 0x2f
	  @cb.endoftrack
	when 0x51
	  rs = RS::PO.new(data)
	  tempo = rs.geti24
	  @cb.settempo(tempo)
	when 0x54
	  rs = RS::PO.new(data)
	  hr = rs.getc
	  tc = [24, 25, 29, 30][(hr >> 5) & 0x3]
	  hr &= 0x1f
	  mn = rs.getc
	  se = rs.getc
	  fr = rs.getc
	  ff = rs.getc
	  @cb.smpteoffset(hr, mn, se, fr, ff, tc)
	when 0x58
	  rs = RS::PO.new(data)
	  nn = rs.getc
	  dd = rs.getc
	  cc = rs.getc
	  bb = rs.getc
	  @cb.timesignature(nn, dd, cc, bb)
	when 0x59
	  rs = RS::PO.new(data)
	  sf = rs.getc
	  mi = rs.getc
	  sf = RS::PO.u2s(sf, 8)
	  @cb.keysignature(sf, mi)
	when 0x7f
	  @cb.sequencerspecific(data)
	else
	  @cb.unknownmeta(type, data)
	end
      end

      def read_track(s)
	@cb.track_start
	rs = RS::PO.new(s)
	running = 0
	until rs.eof?
	  @cb.delta(rs.getl)
	  stat = rs.getc
	  if (stat & 0x80) == 0
	    rs.skip(-1)
	    stat = running
	  else
	    case stat
	    when 0x80..0xef; running = stat
	    when 0xf0..0xf7; running = 0
	    end
	  end
	  case stat
	  when 0x80..0x8f
	    @cb.noteoff(stat & 0xf, rs.getc, rs.getc)
	  when 0x90..0x9f
	    @cb.noteon(stat & 0xf, rs.getc, rs.getc)
	  when 0xa0..0xaf
	    @cb.polyphonickeypressure(stat & 0xf, rs.getc, rs.getc)
	  when 0xb0..0xbf
	    n = rs.getc
	    v = rs.getc
	    if n < 0x78
	      @cb.controlchange(stat & 0xf, n, v)
	    else
	      case n
	      when 0x78; @cb.allsoundoff(stat & 0xf)
	      when 0x79; @cb.resetallcontrollers(stat & 0xf)
	      when 0x7a; @cb.localcontrol(stat & 0xf, v)
	      when 0x7b; @cb.allnotesoff(stat & 0xf)
	      when 0x7c; @cb.omnioff(stat & 0xf)
	      when 0x7d; @cb.omnion(stat & 0xf)
	      when 0x7e; @cb.monomode(stat & 0xf, v)
	      when 0x7f; @cb.polymode(stat & 0xf)
	      end
	    end
	  when 0xc0..0xcf
	    @cb.programchange(stat & 0xf, rs.getc)
	  when 0xd0..0xdf
	    @cb.channelpressure(stat & 0xf, rs.getc)
	  when 0xe0..0xef
	    lsb = rs.getc
	    msb = rs.getc
	    val = (lsb | msb << 7) - 0x2000
	    @cb.pitchbendchange(stat & 0xf, val)
	  when 0xf0, 0xf7
	    len = rs.getl
	    data = rs.getn(len)
	    if stat == 0xf0
	      @cb.exclusivef0(data)
	    else
	      @cb.exclusivef7(data)
	    end
	  when 0xff
	    type = rs.getc
	    len = rs.getl
	    data = rs.getn(len)
	    read_meta(type, data)
	  else
	    until rs.eof?
	      unless (rs.getc & 0x80) == 0
		rs.skip(-1)
		break
	      end
	    end
	  end
	end
	@cb.track_end
      end

      private :read_header, :read_meta, :read_track

      def get_from_macbin
	begin
	  if @s[0, 1] == "\000" && @s[74,1] == "\000" &&
	     @s[82,1] == "\000" && @s[65,4] == 'Midi'
	    @s[128,@s[83,4].unpack('N')[0]]
	  end
	rescue
	end
      end

      def get_from_rmid
	begin
	  if @s[0,4] == 'RIFF' && @s[8,4] == 'RMID'
	    @s[20,@s[16,4].unpack('V')[0]]
	  end
	rescue
	end
      end

      private :get_from_macbin, :get_from_rmid

      def read
	begin
	  rs = RS::PO.new(get_from_macbin || get_from_rmid || @s)
	  ckid = rs.getn(4)
	  unless ckid == 'MThd'
	    @cb.error('not an SMF')
	  end
	  rs.skip(-4)
	  until rs.eof?
	    ckid = rs.getn(4)
	    leng = rs.geti32
	    body = rs.getn(leng)
	    case ckid
	    when 'MThd'
	      read_header(body)
	    when 'MTrk'
	      read_track(body)
	    else
	      @cb.unknownchunk(ckid, body)
	    end
	  end
	rescue EOFError
	  @cb.error('unexpected EOF')
	end
	@cb.result
      end

    end

    class WS

      class PO

	def self.s2u(s, w) s += 2**w if s < 0; s end

#	def initialize() @str = '' end
	def initialize() @arr = [] end

#	def puts(s) @str << s end
#	def putc(c) @str << c end

	unless String === '0'[0]

	  def puts(s) @arr << s     end
	  def putc(c) @arr << c.chr end

	  def putl(v)
	    s = ''
	    begin
	      s << (v & 0x7f | 0x80)
	      v >>= 7
	    end until v.zero?
	    s[0] &= 0x7f
	    s.reverse!
	    puts(s)
	  end

	else

	  def puts(s) @arr << s.dup.force_encoding('ascii-8bit') end
	  def putc(c) @arr << c.chr.force_encoding('ascii-8bit') end

	  def putl(v)
	    s = ''.force_encoding('ascii-8bit')
	    begin
	      s << (v & 0x7f | 0x80)
	      v >>= 7
	    end until v.zero?
	    s[0] = (s.ord & 0x7f).chr
	    s.reverse!
	    puts(s)
	  end

	end

	def puti(n, u)
	  n.times do |i|
	    putc((u >> (n - i - 1) * 8) & 0xff)
	  end
	end

	def puti16(u) puti(2, u) end
	def puti24(u) puti(3, u) end
	def puti32(u) puti(4, u) end

#	def to_s() @str.dup end
	def to_s() @arr.join end

      end

      def initialize(o, cb) @o, @cb = o, cb end

      def read_meta(ev)
	case ev
	when SequenceNumber
	  @cb.sequencenumber(ev.num)
	when Text
	  case ev
	  when GeneralPurposeText; @cb.generalpurposetext(ev.text)
	  when CopyrightNotice;    @cb.copyrightnotice(ev.text)
	  when TrackName;          @cb.trackname(ev.text)
	  when InstrumentName;     @cb.instrumentname(ev.text)
	  when Lyric;              @cb.lyric(ev.text)
	  when Marker;             @cb.marker(ev.text)
	  when CuePoint;           @cb.cuepoint(ev.text)
	  when ProgramName;        @cb.programname(ev.text)
	  when DeviceName;         @cb.devicename(ev.text)
	  when Text0A;             @cb.text0a(ev.text)
	  when Text0B;             @cb.text0b(ev.text)
	  when Text0C;             @cb.text0c(ev.text)
	  when Text0D;             @cb.text0d(ev.text)
	  when Text0E;             @cb.text0e(ev.text)
	  when Text0F;             @cb.text0f(ev.text)
	  end
	when ChannelPrefix
	  @cb.channelprefix(ev.ch)
	when MIDIPort
	  @cb.midiport(ev.num)
	when EndOfTrack
	  @cb.endoftrack
	when SetTempo
	  @cb.settempo(ev.tempo)
	when SMPTEOffset
	  @cb.smpteoffset(ev.hr, ev.mn, ev.se, ev.fr, ev.ff, ev.tc)
	when TimeSignature
	  @cb.timesignature(ev.nn, ev.dd, ev.cc, ev.bb)
	when KeySignature
	  @cb.keysignature(ev.sf, ev.mi)
	when SequencerSpecific
	  @cb.sequencerspecific(ev.data)
	else
	  @cb.unknownmeta(ev.type, ev.data)
	end
      end

      def read_track(tr)
	@cb.track_start
	offset = 0
	tr.each do |ev|
	  @cb.delta(ev.offset - offset)
	  case ev
	  when NoteOff
	    if ev.fake?
	      @cb.noteon(ev.ch, ev.note, 0)
	    else
	      @cb.noteoff(ev.ch, ev.note, ev.vel)
	    end
	  when NoteOn
	    @cb.noteon(ev.ch, ev.note, ev.vel)
	  when PolyphonicKeyPressure
	    @cb.polyphonickeypressure(ev.ch, ev.note, ev.val)
	  when ControlChange
	    @cb.controlchange(ev.ch, ev.num, ev.val)
	  when ProgramChange
	    @cb.programchange(ev.ch, ev.num)
	  when ChannelPressure
	    @cb.channelpressure(ev.ch, ev.val)
	  when PitchBendChange
	    @cb.pitchbendchange(ev.ch, ev.val)
	  when AllSoundOff
	    @cb.allsoundoff(ev.ch)
	  when ResetAllControllers
	    @cb.resetallcontrollers(ev.ch)
	  when LocalControl
	    @cb.localcontrol(ev.ch, ev.val)
	  when AllNotesOff
	    @cb.allnotesoff(ev.ch)
	  when OmniOff
	    @cb.omnioff(ev.ch)
	  when OmniOn
	    @cb.omnion(ev.ch)
	  when MonoMode
	    @cb.monomode(ev.ch, ev.val)
	  when PolyMode
	    @cb.polymode(ev.ch)
	  when ExclusiveF0
	    @cb.exclusivef0(ev.data)
	  when ExclusiveF7
	    @cb.exclusivef7(ev.data)
	  when Meta
	    read_meta(ev)
	  end
	  offset = ev.offset
	end
	@cb.track_end
      end

      private :read_meta, :read_track

      def read
	@cb.header(@o.format, @o.ntrks, @o.division, @o.tc)
	@o.each do |ck|
	  case ck
	  when Track
	    read_track(ck)
	  else
	    @cb.unknownchunk(ck.ckid, ck.body)
	  end
	end
	@cb.result
      end

    end

    class XSCallback

      def header(format, ntrks, division, tc) end

      def track_start() end
      def track_end() end

      def unknownchunk(ckid, body) end
      def delta(delta) end

      def noteoff(ch, note, vel) end
      def noteon(ch, note, vel) end
      def polyphonickeypressure(ch, note, val) end
      def controlchange(ch, num, val) end
      def programchange(ch, num) end
      def channelpressure(ch, val) end
      def pitchbendchange(ch, val) end

      def allsoundoff(ch) end
      def resetallcontrollers(ch) end
      def localcontrol(ch, val) end
      def allnotesoff(ch) end
      def omnioff(ch) end
      def omnion(ch) end
      def monomode(ch, val) end
      def polymode(ch) end

      def exclusivef0(data) end
      def exclusivef7(data) end

      def sequencenumber(num) end

      def generalpurposetext(text) end
      def copyrightnotice(text) end
      def trackname(text) end
      def instrumentname(text) end
      def lyric(text) end
      def marker(text) end
      def cuepoint(text) end
      def programname(text) end
      def devicename(text) end
      def text0a(text) end
      def text0b(text) end
      def text0c(text) end
      def text0d(text) end
      def text0e(text) end
      def text0f(text) end

      def channelprefix(ch) end
      def midiport(num) end
      def endoftrack() end
      def settempo(tempo) end
      def smpteoffset(hr, mn, se, fr, ff, tc) end
      def timesignature(nn, dd, cc, bb) end
      def keysignature(sf, mi) end
      def sequencerspecific(data) end

      def unknownmeta(type, data) end

      def result() end

      def error(mesg) end
      def warn(mesg) end

    end

    module Checker

      def cr(n, v, e, w=nil)
	unless e === v
	  error("#{n}: out of range")
	return
	end
	if w
	  unless w === v
	    warn("#{n}: out of range")
	  end
	end
      end

      private :cr

      def header(format, ntrks, division, tc)
	cr('header/format', format, (0..2**16-1), (0..2))
	if format == 0
	  cr('header/ntrks', ntrks, (0..2**16-1), (1..1))
	else
	  cr('header/ntrks', ntrks, (0..2**16-1), (1..2**16-1))
	end
	unless tc
	  cr('header/division', division, (1..2**15-1))
	else
	  cr('header/division', division, (1..2**8-1))
	  cr('header/tc', tc, (0..2**7))
	  unless [24, 25, 29, 30].include? tc
	    warn('header/tc: invalid format')
	  end
	end
	super
      end

      def chunk_body(body)
	unless body.length <= 2**32-1
	  error('chunk size: too large')
	end
      end

      private :chunk_body

      def delta(delta)
	cr('delta', delta, (0..2**28-1))
	super
      end

      def noteoff(ch, note, vel)
	cr('noteoff/ch', ch, (0..2**4-1))
	cr('noteoff/note', note, (0..2**7-1))
	cr('noteoff/vel', vel, (0..2**7-1))
	super
      end

      def noteon(ch, note, vel)
	cr('noteon/ch', ch, (0..2**4-1))
	cr('noteon/note', note, (0..2**7-1))
	cr('noteon/vel', vel, (0..2**7-1))
	super
      end

      def polyphonickeypressure(ch, note, val)
	cr('polyphonickeypressure/ch', ch, (0..2**4-1))
	cr('polyphonickeypressure/note', note, (0..2**7-1))
	cr('polyphonickeypressure/val', val, (0..2**7-1))
	super
      end

      def controlchange(ch, num, val)
	cr('controlchange/ch', ch, (0..2**4-1))
	cr('controlchange/num', num, (0..0x77))
	cr('controlchange/val', val, (0..2**7-1))
	super
      end

      def programchange(ch, num)
	cr('programchange/ch', ch, (0..2**4-1))
	cr('programchange/num', num, (0..2**7-1))
	super
      end

      def channelpressure(ch, val)
	cr('channelpressure/ch', ch, (0..2**4-1))
	cr('channelpressure/val', val, (0..2**7-1))
	super
      end

      def pitchbendchange(ch, val)
	cr('pitchbendchange/ch', ch, (0..2**4-1))
	cr('pitchbendchange/val', val, (-2**13..2**13-1))
	super
      end

      def no_channelmodemessage(ch, num, val)
	cr('channelmodemessage/ch', ch, (0..2**4-1))
	cr('channelmodemessage/num', num, (0x78..0x7f))
	unless num == 0x7e
	  cr('channelmodemessage/val', val, (0..2**7-1))
	else
	  cr('channelmodemessage/val', val, (0..2**7-1), (0..16))
	end
      end

      private :no_channelmodemessage

      def allsoundoff(ch) no_channelmodemessage(ch, 0x78, 0); super end
      def resetallcontrollers(ch) no_channelmodemessage(ch, 0x79, 0); super end
      def localcontrol(ch, val) no_channelmodemessage(ch, 0x7a, val); super end
      def allnotesoff(ch) no_channelmodemessage(ch, 0x7b, 0); super end
      def omnioff(ch) no_channelmodemessage(ch, 0x7c, 0); super end
      def omnion(ch) no_channelmodemessage(ch, 0x7d, 0); super end
      def monomode(ch, val) no_channelmodemessage(ch, 0x7e, val); super end
      def polymode(ch) no_channelmodemessage(ch, 0x7f, 0); super end

      def exclusivef0(data)
	cr('exclusive size', data.length, (0..2**28-1), (1..2**28-1))
	super
      end

      def exclusivef7(data)
	cr('exclusive size', data.length, (0..2**28-1), (1..2**28-1))
	super
      end

      def sequencenumber(num)
	cr('sequencenumber/num', num, (0..2**16-1))
	super
      end

      def no_text(type, text)
	cr('text size', text.length, (0..2**28-1), (1..2**28-1))
      end

      private :no_text

      def generalpurposetext(text) no_text(0x1, text); super end
      def copyrightnotice(text) no_text(0x2, text); super end
      def trackname(text) no_text(0x3, text); super end
      def instrumentname(text) no_text(0x4, text); super end
      def lyric(text) no_text(0x5, text); super end
      def marker(text) no_text(0x6, text); super end
      def cuepoint(text) no_text(0x7, text); super end
      def programname(text) no_text(0x8, text); super end
      def devicename(text) no_text(0x9, text); super end
      def text0a(text) no_text(0xa, text); super end
      def text0b(text) no_text(0xb, text); super end
      def text0c(text) no_text(0xc, text); super end
      def text0d(text) no_text(0xd, text); super end
      def text0e(text) no_text(0xe, text); super end
      def text0f(text) no_text(0xf, text); super end

      def channelprefix(ch)
	cr('channelprefix/ch', ch, (0..2**8-1), (0..2**4-1))
	super
      end

      def midiport(num)
	cr('midiport/num', num, (0..2**8-1))
	super
      end

      def settempo(tempo)
	cr('settempo/tempo', tempo, (1..2**24-1))
	super
      end

      def smpteoffset(hr, mn, se, fr, ff, tc)
	cr('smpteoffset/hr', hr, (0..2**8-1), (1..23))
	cr('smpteoffset/mn', mn, (0..2**8-1), (1..59))
	cr('smpteoffset/se', se, (0..2**8-1), (1..59))
	cr('smpteoffset/fr', fr, (0..2**8-1), (1..29))
	cr('smpteoffset/ff', ff, (0..2**8-1), (1..99))
	cr('smpteoffset/tc', tc, (0..2**8-1))
	unless [24, 25, 29, 30].include? tc
	  warn('smpteoffset/tc: invalid format')
	end
	super
      end

      def timesignature(nn, dd, cc, bb)
	cr('timesignature/nn', nn, (1..2**8-1))
	cr('timesignature/dd', dd, (0..2**8-1))
	cr('timesignature/cc', cc, (1..2**8-1))
	cr('timesignature/bb', bb, (1..2**8-1))
	super
      end

      def keysignature(sf, mi)
	cr('keysignature/sf', sf, (-2**7..2**7-1))
	cr('keysignature/mi', mi, (0..1))
	super
      end

      def sequencerspecific(data)
	unless data.length <= 2**28-1
	  error('sequencerspecific: too large')
	end
	super
      end

      def unknownmeta(type, data)
	unless data.length <= 2**28-1
	  error('unknownmeta: too large')
	end
	super
      end

    end

    class Decode < XSCallback

#      include Checker

      def header(format, ntrks, division, tc)
	@sq = Sequence.new(format, division, tc)
      end

      def track_start
	@sq << (@tr = Track.new)
	@offset = 0
      end

      def delta(delta) @offset += delta end

      def noteoff(ch, note, vel)
	@tr << NoteOff.new(@offset, ch, note, vel)
      end

      def noteon(ch, note, vel)
	if vel == 0
	  @tr << NoteOff.new(@offset, ch, note, nil)
	else
	  @tr << NoteOn.new(@offset, ch, note, vel)
	end
      end

      def polyphonickeypressure(ch, note, val)
	@tr << PolyphonicKeyPressure.new(@offset, ch, note, val)
      end

      def controlchange(ch, num, val)
	@tr << ControlChange.new(@offset, ch, num, val)
      end

      def programchange(ch, num)
	@tr << ProgramChange.new(@offset, ch, num)
      end

      def channelpressure(ch, val)
	@tr << ChannelPressure.new(@offset, ch, val)
      end

      def pitchbendchange(ch, val)
	@tr << PitchBendChange.new(@offset, ch, val)
      end

      def allsoundoff(ch)
	@tr << AllSoundOff.new(@offset, ch)
      end

      def resetallcontrollers(ch)
	@tr << ResetAllControllers.new(@offset, ch)
      end

      def localcontrol(ch, val)
	@tr << LocalControl.new(@offset, ch, val)
      end

      def allnotesoff(ch)
	@tr << AllNotesOff.new(@offset, ch)
      end

      def omnioff(ch)
	@tr << OmniOff.new(@offset, ch)
      end

      def omnion(ch)
	@tr << OmniOn.new(@offset, ch)
      end

      def monomode(ch, val)
	@tr << MonoMode.new(@offset, ch, val)
      end

      def polymode(ch)
	@tr << PolyMode.new(@offset, ch)
      end

      def exclusivef0(data)
	@tr << ExclusiveF0.new(@offset, data)
      end

      def exclusivef7(data)
	@tr << ExclusiveF7.new(@offset, data)
      end

      def sequencenumber(num)
	@tr << SequenceNumber.new(@offset, num)
      end

      def generalpurposetext(text)
	@tr << GeneralPurposeText.new(@offset, text)
      end

      def copyrightnotice(text)
	@tr << CopyrightNotice.new(@offset, text)
      end

      def trackname(text)
	@tr << TrackName.new(@offset, text)
      end

      def instrumentname(text)
	@tr << InstrumentName.new(@offset, text)
      end

      def lyric(text)
	@tr << Lyric.new(@offset, text)
      end

      def marker(text)
	@tr << Marker.new(@offset, text)
      end

      def cuepoint(text)
	@tr << CuePoint.new(@offset, text)
      end

      def programname(text)
	@tr << ProgramName.new(@offset, text)
      end

      def devicename(text)
	@tr << DeviceName.new(@offset, text)
      end

      def text0a(text)
	@tr << Text0A.new(@offset, text)
      end

      def text0b(text)
	@tr << Text0B.new(@offset, text)
      end

      def text0c(text)
	@tr << Text0C.new(@offset, text)
      end

      def text0d(text)
	@tr << Text0D.new(@offset, text)
      end

      def text0e(text)
	@tr << Text0E.new(@offset, text)
      end

      def text0f(text)
	@tr << Text0F.new(@offset, text)
      end

      def channelprefix(ch)
	@tr << ChannelPrefix.new(@offset, ch)
      end

      def midiport(num)
	@tr << MIDIPort.new(@offset, num)
      end

      def endoftrack
	@tr << EndOfTrack.new(@offset)
      end

      def settempo(tempo)
	@tr << SetTempo.new(@offset, tempo)
      end

      def smpteoffset(hr, mn, se, fr, ff, tc)
	@tr << SMPTEOffset.new(@offset, hr, mn, se, fr, ff, tc)
      end

      def timesignature(nn, dd, cc, bb)
	@tr << TimeSignature.new(@offset, nn, dd, cc, bb)
      end

      def keysignature(sf, mi)
	@tr << KeySignature.new(@offset, sf, mi)
      end

      def sequencerspecific(data)
	@tr << SequencerSpecific.new(@offset, data)
      end

      def result() @sq end

      def error(mesg) raise ReadError, mesg end

    end

    class Encode < XSCallback

#      include Checker

      @@replace_noteoff = false

      def header(format, ntrks, division, tc)
	@ws = WS::PO.new
	@ws.puts('MThd')
	@ws.puti32(6)
	@ws.puti16(format)
	@ws.puti16(ntrks)
	if tc
	  div1 = 0x100 - tc
	  div2 = division
	else
	  div1 = division >> 8
	  div2 = division & 0xff
	end
	@ws.putc(div1)
	@ws.putc(div2)
      end

      def track_start
	@ev = WS::PO.new
	@running = 0
	@cieot = false
      end

      def chunk_body(body) end

      private :chunk_body

      def track_end
	@ws.puts('MTrk')
	unless @cieot
	  delta(0)
	  endoftrack
	end
	ev = @ev.to_s
	chunk_body(ev)
	@ws.puti32(ev.length)
	@ws.puts(ev)
      end

      def unknownchunk(ckid, body)
	@ws.puts(ckid)
	chunk_body(ev)
	@ws.puti32(body.length)
	@ws.puts(body)
      end

      def de
	@ev.putl(@delta)
      end

      def sb(stat)
	@ev.putc(stat) unless stat == @running
	case stat
	when 0x80..0xef; @running = stat
	when 0xf0..0xf7; @running = 0
	end
      end

      def db(data)
	@ev.putc(data & 0x7f)
      end

      private :de, :sb, :db

      def delta(delta) @delta = delta end

      def noteoff(ch, note, vel)
	de
	if @@replace_noteoff
	  sb(ch | 0x90)
	  db(note)
	  db(0)
	else
	  sb(ch | 0x80)
	  db(note)
	  db(vel)
	end
      end

      def noteon(ch, note, vel)
	de
	sb(ch | 0x90)
	db(note)
	db(vel)
      end

      def polyphonickeypressure(ch, note, val)
	de
	sb(ch | 0xa0)
	db(note)
	db(val)
      end

      def controlchange(ch, num, val)
	de
	sb(ch | 0xb0)
	db(num)
	db(val)
      end

      def programchange(ch, num)
	de
	sb(ch | 0xc0)
	db(num)
      end

      def channelpressure(ch, val)
	de
	sb(ch | 0xd0)
	db(val)
      end

      def pitchbendchange(ch, val)
	de
	sb(ch | 0xe0)
	val += 0x2000
	lsb =  val       & 0x7f
	msb = (val >> 7) & 0x7f
	db(lsb)
	db(msb)
      end

      def channelmodemessage(ch, num, val)
	de
	sb(ch | 0xb0)
	db(num)
	db(val)
      end

      private :channelmodemessage

      def allsoundoff(ch) channelmodemessage(ch, 0x78, 0) end
      def resetallcontrollers(ch) channelmodemessage(ch, 0x79, 0) end
      def localcontrol(ch, val) channelmodemessage(ch, 0x7a, val) end
      def allnotesoff(ch) channelmodemessage(ch, 0x7b, 0) end
      def omnioff(ch) channelmodemessage(ch, 0x7c, 0) end
      def omnion(ch) channelmodemessage(ch, 0x7d, 0) end
      def monomode(ch, val) channelmodemessage(ch, 0x7e, val) end
      def polymode(ch) channelmodemessage(ch, 0x7f, 0) end

      def exclusivef0(data)
	de
	@ev.putc(0xf0)
	@ev.putl(data.length)
	@ev.puts(data)
      end

      def exclusivef7(data)
	de
	@ev.putc(0xf7)
	@ev.putl(data.length)
	@ev.puts(data)
      end

      def sequencenumber(num)
	de
	@ev.putc(0xff)
	@ev.putc(0x0)
	@ev.putl(2)
	@ev.puti16(num)
      end

      def text(type, text)
	de
	@ev.putc(0xff)
	@ev.putc(type)
	@ev.putl(text.length)
	@ev.puts(text)
      end

      private :text

      def generalpurposetext(text) text(0x1, text) end
      def copyrightnotice(text) text(0x2, text) end
      def trackname(text) text(0x3, text) end
      def instrumentname(text) text(0x4, text) end
      def lyric(text) text(0x5, text) end
      def marker(text) text(0x6, text) end
      def cuepoint(text) text(0x7, text) end
      def programname(text) text(0x8, text) end
      def devicename(text) text(0x9, text) end
      def text0a(text) text(0xa, text) end
      def text0b(text) text(0xb, text) end
      def text0c(text) text(0xc, text) end
      def text0d(text) text(0xd, text) end
      def text0e(text) text(0xe, text) end
      def text0f(text) text(0xf, text) end

      def channelprefix(ch)
	de
	@ev.putc(0xff)
	@ev.putc(0x20)
	@ev.putl(1)
	@ev.putc(ch)
      end

      def midiport(num)
	de
	@ev.putc(0xff)
	@ev.putc(0x21)
	@ev.putl(1)
	@ev.putc(num)
      end

      def endoftrack
	de
	@ev.putc(0xff)
	@ev.putc(0x2f)
	@ev.putl(0)
	@cieot = true
      end

      def settempo(tempo)
	de
	@ev.putc(0xff)
	@ev.putc(0x51)
	@ev.putl(3)
	@ev.puti24(tempo)
      end

      def smpteoffset(hr, mn, se, fr, ff, tc)
	unless [24, 25, 29, 30].include? tc
	  warn('smpteoffset/tc: invalid format')
	end
	de
	@ev.putc(0xff)
	@ev.putc(0x54)
	@ev.putl(5)
	hr |= ({24=>0, 25=>1, 29=>2, 30=>3}[tc] || 0) << 5
	@ev.putc(hr)
	@ev.putc(mn)
	@ev.putc(se)
	@ev.putc(fr)
	@ev.putc(ff)
      end

      def timesignature(nn, dd, cc, bb)
	de
	@ev.putc(0xff)
	@ev.putc(0x58)
	@ev.putl(4)
	@ev.putc(nn)
	@ev.putc(dd)
	@ev.putc(cc)
	@ev.putc(bb)
      end

      def keysignature(sf, mi)
	sf = WS::PO.s2u(sf, 8)
	de
	@ev.putc(0xff)
	@ev.putc(0x59)
	@ev.putl(2)
	@ev.putc(sf)
	@ev.putc(mi)
      end

      def sequencerspecific(data)
	de
	@ev.putc(0xff)
	@ev.putc(0x7f)
	@ev.putl(data.length)
	@ev.puts(data)
      end

      def unknownmeta(type, data)
	de
	@ev.putc(0xff)
	@ev.putc(type)
	@ev.putl(data.length)
	@ev.puts(data)
      end

      def result() @ws.to_s end

      def error(mesg) raise ReadError, mesg end

    end

    class << self

      unless String === '0'[0]

	def decode(s)
	  self::RS.new(s, self::Decode.new).read
	end

      else

	def decode(s)
	  s = s.dup.force_encoding('ascii-8bit')
	  self::RS.new(s, self::Decode.new).read
	end

      end

      def read(io)
	decode(io.binmode.read)
      end

      def decoceio(io)
	warn('decodeio is deprecated; use read') if $VERBOSE
	read(io)
      end

      def load(fn)
	open(fn) do |io|
	  read(io)
	end
      end

      def decodefile(fn)
	warn('decodefile is deprecated; use load') if $VERBOSE
	load(fn)
      end

    end

    def encode
      self.class::WS.new(self, self.class::Encode.new).read
    end

    def write(io)
      io.binmode.write(encode)
    end

    def encodeio(io)
      warn('encodeio is deprecated; use write') if $VERBOSE
      write(io)
    end

    def save(fn)
      open(fn, 'w') do |io|
	write(io)
      end
    end

    def encodefile(fn)
      warn('encodefile is deprecated; use save') if $VERBOSE
      save(fn)
    end

  end

end
