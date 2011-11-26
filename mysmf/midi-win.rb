#! /usr/bin/env ruby

# play-win.rb: Written by Tadayoshi Funaba 2005,2006
# $Id: play-win.rb,v 1.4 2006-11-10 21:57:06+09 tadf Exp $

# midi-win.rb: modified by Yo Kubota 2009.07.31

require 'smf'
require 'smf/toy/tempomap'
require 'Win32API'
include  SMF

module SMF

  class Kernel32 < Win32API

    def initialize(proc, import, export)
      super('kernel32', proc, import, export)
    end

  end

  class WinMM < Win32API

    def initialize(proc, import, export)
      super('winmm', proc, import, export)
    end

  end

  module WinBase

    NORMAL_PRIORITY_CLASS = 0x00000020
    IDEL_PRIORITY_CLASS = 0x00000040
    HIGH_PRIORITY_CLASS = 0x00000080
    REALTIME_PRIORITY_CLASS = 0x00000100

    @@GetCurrentProcess = Kernel32.new('GetCurrentProcess', %w(), 'l')
    @@SetPriorityClass = Kernel32.new('SetPriorityClass', %w(l l), 'l')

    def setpriorityclass(prc=NORMAL_PRIORITY_CLASS)
      prh = @@GetCurrentProcess.call
      @@SetPriorityClass.call(prh, prc)
    end

    module_function :setpriorityclass

  end

  class DevMidiOut

    @@GetNumDevs = WinMM.new('midiOutGetNumDevs', %w(), 'l')
    @@GetDevCaps = WinMM.new('midiOutGetDevCaps', %w(l p l), 'l')
    @@Open = WinMM.new('midiOutOpen', %w(p l l l l), 'l')
    @@Reset = WinMM.new('midiOutReset', %w(l), 'l')
    @@Close = WinMM.new('midiOutClose', %w(l), 'l')
    @@ShortMsg = WinMM.new('midiOutShortMsg', %w(l l), 'l')
    @@LongMsg = WinMM.new('midiOutLongMsg', %w(l p l), 'l')
    @@PrepareHeader = WinMM.new('midiOutPrepareHeader', %w(l p l), 'l')
    @@UnprepareHeader = WinMM.new('midiOutUnprepareHeader', %w(l p l), 'l')

    def self.getnumdev() @@GetNumDevs.call end

    def self.getdevcaps(did)
      caps = "\000" * 52
      @@GetDevCaps.call(did, caps, caps.size)
      caps.unpack('S2LZ32S4L')
    end

    def initialize(did)
      mo = "\000" * 4
      @@Open.call(mo, did, 0, 0, 0)
      @mo = mo.unpack('L')[0]
    end

    def reset() @@Reset.call(@mo) end
    def close() @@Close.call(@mo) end
    def shortmsg(msg) @@ShortMsg.call(@mo, msg) end

    def longmsg(msg)
      moh = [msg, msg.size, 0, 0, 0, 0, 0, 0, ''].pack('PL7A32')
      @@PrepareHeader.call(@mo, moh, moh.size)
      @@LongMsg.call(@mo, moh, moh.size)
      @@UnprepareHeader.call(@mo, moh, moh.size)
    end

  end

  class Sequence

    class Timer

      def initialize() @start = Time.now end
      def elapse() Time.now - @start end

    end

    class Play < XSCallback

      def initialize(tm, num) @tm, @num = tm, num end

      def header(format, ntrks, division, tc)
        WinBase.setpriorityclass(WinBase::HIGH_PRIORITY_CLASS)
        ndev = DevMidiOut.getnumdev
        puts(DevMidiOut.getdevcaps(@num)[3]) if $VERBOSE
        unless @num < ndev
          raise 'device not available'
        end
        @mo = DevMidiOut.new(@num)
      end

      def track_start() @offset = 0 end

      def delta(delta)
        @timer ||= Timer.new
        if delta.nonzero?
          @offset += delta
          e = @tm.offset2elapse(@offset) - @timer.elapse
          if e > 0
            sleep(e.to_f)
          end
        end
      end

      def midimsg(sb, db1, db2=0)
        @mo.shortmsg(sb | (db1 << 8) | (db2 << 16))
      end

#      private :midimsg

      def noteoff(ch, note, vel) midimsg(ch | 0x80, note, vel) end
      def noteon(ch, note, vel) midimsg(ch | 0x90, note, vel) end

      def polyphonickeypressure(ch, note, val)
        midimsg(ch | 0xa0, note, val)
      end

      def controlchange(ch, num, val) midimsg(ch | 0xb0, num, val) end
      def programchange(ch, num) midimsg(ch | 0xc0, num) end
      def channelpressure(ch, val) midimsg(ch | 0xd0, val) end

      def pitchbendchange(ch, val)
        val += 0x2000
        lsb =  val       & 0x7f
        msb = (val >> 7) & 0x7f
        midimsg(ch | 0xe0, lsb, msb)
      end

      def channelmodemessage(ch, num, val) controlchange(ch, num, val) end

      private :channelmodemessage

      def allsoundoff(ch) channelmodemessage(ch, 0x78, 0) end
      def resetallcontrollers(ch) channelmodemessage(ch, 0x79, 0) end
      def localcontrol(ch, val) channelmodemessage(ch, 0x7a, val) end
      def allnotesoff(ch) channelmodemessage(ch, 0x7b, 0) end
      def omnioff(ch) channelmodemessage(ch, 0x7c, 0) end
      def omnion(ch) channelmodemessage(ch, 0x7d, 0) end
      def monomode(ch, val) channelmodemessage(ch, 0x7e, val) end
      def polymode(ch) channelmodemessage(ch, 0x7f, 0) end

      def exclusivefx(data) @mo.longmsg(data) end

      private :exclusivefx

      def exclusivef0(data) exclusivefx("\xf0" + data) end
      def exclusivef7(data) exclusivefx(data) end

      def result() @mo.close end

    end

    def play(num=0)
      j = join
      tm = TempoMap.new(j)
      WS.new(j, Play.new(tm, num)).read
    end

  end

end

