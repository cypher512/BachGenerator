# macro.rb: Written by Tadayoshi Funaba 1999-2006
# $Id: macro.rb,v 1.5 2006-11-10 21:58:21+09 tadf Exp $

require 'smf'
require 'smf/toy/gm'
require 'rational'

module SMF

  class Sheet

    def initialize(sq)
      @sq = sq
      @co = []
      gt(0)
    end

    def snap(ev)
      @co << ev
    end

    def gt(n) @sq[n] ||= Track.new end

    private :gt

    def re(v, l, h=nil)
      if v && l && v < l then v = l end
      if v && h && v > h then v = h end
      v
    end

    private :re

    def generate
      i = 0
      @co = @co.sort_by{|x| [x[:of], i += 1]}

      i = 0
      lev = {}
      uniq = {}
      @co.each do |ev|

	ev.each_key do |key|

	  if ev[key] == nil || ev[key] == lev[key]
	    next
	  end

	  case key.to_s
	  when /\A_(no|tx|ke)/
	    k = format('%d:%s', i, key)
	    uniq[k] = [i, key, ev]
	  when /\A(te|ti|pp|co|mo|pr|cp|pi|gm)/
	    k = format('%s:%s', ev[:of], key)
	    if uniq[k]
	      uniq[k] = [uniq[k][0], key, ev]
	    else
	      uniq[k] = [i, key, ev]
	    end
	    lev[key] = ev[key]
	  end

	  i += 1

	end

      end

      co2 = uniq.values.sort_by{|x| x[0]}

      wh = @sq.division * 4

      ke = {}

      co2.each do |_, key, ev|
	tr = ev[:tr].to_i; tr = re(tr, 0, 65535) # 0/2**16-1
	ch = ev[:ch].to_i; ch = re(ch, 0, 15)    # 0/2**4-1
	of = ev[:of];      of = re(of, 0)
	oc = ev[:oc]
	le = ev[:le];      le = re(le, 0.to_r)
	du = ev[:du];      du = re(du, 0.to_r)
	ve = ev[:ve];      ve = re(ve, 0.to_r, 1.to_r)
	sf, = ev[:ke];     sf ||= 0
	v = ev[key]

	case key.to_s

	when '_no'
	  t = gt(tr)
	  o = (of * wh).round
	  p = ((of + le * du) * wh).round
	  na, s1, s12 = v
	  unless s1
	    unless ke[sf]
	      ke[sf] = [0] * 12
	      d = if sf < 0 then -1 else +1 end
	      b = if d == 1 then 5 else 11 end
	      sf.to_i.abs.times do |i|
		n = (b + 7 * i * d) % 12
		ke[sf][n] += d
	      end
	    end
	    s1 = ke[sf][na]
	  end
	  s1  ||=0
	  s12 ||=0
	  n = (na + s1 + s12 + oc * 12 + 12).to_i
	  if n < 0   then n =        n        % 12 end
	  if n > 127 then n = 116 + (n - 116) % 12 end
	  w = (ve * 127).round
	  if w != 0
	    t << NoteOn.new(o, ch, n, w)
	    t << NoteOff.new(p, ch, n, 64)
	  end

	when '_tx'
	  n = if /\A(co|sq):/ =~ v then 0 else tr end
	  t = gt(n)
	  o = (of * wh).round
	  case v
	  when /\Ate:/; t << GeneralPurposeText.new(o, $')
	  when /\Aco:/; t << CopyrightNotice.new(o, $')
	  when /\Asq:/; t << SequenceName.new(o, $')
	  when /\Atr:/; t << TrackName.new(o, $')
	  when /\Ain:/; t << InstrumentName.new(o, $')
	  when /\Aly:/; t << Lyric.new(o, $')
	  when /\Ama:/; t << Marker.new(o, $')
	  when /\Acu:/; t << CuePoint.new(o, $')
	  when /\Apr:/; t << ProgramName.new(o, $')
	  when /\Ade:/; t << DeviceName.new(o, $')
	  else;         t << GeneralPurposeText.new(o, v)
	  end

	when '_ke'
	  s, m = v
	  m ||= 0
	  s = re(s, -128, 127) # -2**7/2**7-1
	  m = re(m, 0, 1)      # 0/1
	  t = gt(tr)
	  o = (of * wh).round
	  t << KeySignature.new(o, s.to_i, m.to_i)

	when 'te'
	  v = re(v, 1, 16777215) # 1/2**24-1
	  t = gt(0)
	  o = (of * wh).round
	  t <<  SetTempo.new(o, (60000000 / v).round)

	when 'ti'
	  n, d = v
	  d ||= 4
	  n = re(n, 1, 255) # 1/2**8-1
	  d = re(d, 0, 255) # 0/2**8-1
	  t = gt(0)
	  o = (of * wh).round
	  n, d = n.to_i, d.to_i
	  dd = -1
	  while d != 0
	    d >>= 1
	    dd += 1
	  end
	  c = 96 >> dd
	  t << TimeSignature.new(o, n, dd, c, 8)

	when /\App(\d+)\/\d+\z/
	  n = $1
	  v = re(v, 0, 127) # 0/2**7-1
	  t = gt(tr)
	  o = (of * wh).round
	  t << PolyphonicKeyPressure.new(o, ch, n.to_i, v.to_i)

	when /\Aco(\d+)\/\d+\z/
	  n = $1
	  v = re(v, 0, 127) # 0/2**7-1
	  t = gt(tr)
	  o = (of * wh).round
	  t << ControlChange.new(o, ch, n.to_i, v.to_i)

	when /\Amo(\d+)\/\d+\z/
	  n = $1
	  v = re(v, 0, 127) # 0/2**7-1
	  t = gt(tr)
	  o = (of * wh).round
	  case n.to_i
	  when 0x78; t << AllSoundOff.new(o, ch)
	  when 0x79; t << ResetAllControllers.new(o, ch)
	  when 0x7a; t << LocalControl.new(o, ch, v)
	  when 0x7b; t << AllNotesOff.new(o, ch)
	  when 0x7c; t << OmniOff.new(o, ch)
	  when 0x7d; t << OmniOn.new(o, ch)
	  when 0x7e; t << MonoMode.new(o, ch, v)
	  when 0x7f; t << PolyMode.new(o, ch)
	  end

	when /\Apr\/\d+\z/
	  v = re(v, 0, 127) # 0/2**7-1
	  t = gt(tr)
	  o = (of * wh).round
	  t << ProgramChange.new(o, ch, v.to_i)

	when /\Acp\/\d+\z/
	  v = re(v, 0, 127) # 0/2**7-1
	  t = gt(tr)
	  o = (of * wh).round
	  t << ChannelPressure.new(o, ch, v.to_i)

	when /\Api\/\d+\z/
	  v = re(v, -8192, 8191) # -2**13/2**13-1
	  t = gt(tr)
	  o = (of * wh).round
	  t << PitchBendChange.new(o, ch, v.to_i)

	when 'gm'
	  v = re(v, 0, 2) # 0/2
	  t = gt(0)
	  o = (of * wh).round
	  case v
	  when 0; t << GMSystemOff.new(o)
	  when 1; t << GMSystemOn.new(o)
	  when 2; t << GM2SystemOn.new(o)
	  end

	end

      end

      ev = @co[-1]
      max_of = (if ev then ev[:of] else 0 end)
      o = (max_of * wh).round
      @sq.each do |tr| tr << EndOfTrack.new(o) end

    end

  end

  class Descripter

    def initialize(sh)
      @sh = sh
      @es = []
      @es << {}
      @es[-1][:tr] = 1
      @es[-1][:ch] = 0
      @es[-1][:of] = 0
      @es[-1][:oc] = 4.to_r/1
      @es[-1][:le] = 1.to_r/4
      @es[-1][:du] = 9.to_r/10
      @es[-1][:ve] = 3.to_r/4
    end

    def push() @es.push(@es[-1].dup) end
    def pop() @es.pop end

    def rv(k, ch)
      k = k.to_s
      k.gsub!(/0+(\d)/, '\1')
      case k
      when /\A(pp|co|mo)(\d+)\z/; k += format('/%d', ch)
      when /\A(pr|cp|pi)\z/     ; k += format('/%d', ch)
      end
      k = k.intern
    end

    private :rv

    def [] (k)
      ch = @es[-1][:ch]
      k = rv(k, ch.to_i)
      @es[-1][k]
    end

    def []=(k, v)
      ch = @es[-1][:ch]
      k = rv(k, ch.to_i)
      @es[-1][k] = v
    end

    def snap() @sh.snap(@es[-1].dup) end

  end

end
