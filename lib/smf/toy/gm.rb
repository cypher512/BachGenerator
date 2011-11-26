# gm.rb: Written by Tadayoshi Funaba 2005
# $Id: gm.rb,v 1.2 2005-07-17 17:07:37+09 tadf Exp $

module SMF

  [ ['BankSelectMSB', 0],
    ['ModulationDepthMSB', 1],
    ['PortamentoTimeMSB', 5],
    ['DataEntryMSB', 6],
    ['ChannelVolumeMSB', 7],
    ['PanMSB', 10],
    ['ExpressioMSB', 11],
    ['BankSelectLSB', 32 + 0],
    ['ModulationDepthLSB', 32 + 1],
    ['PortamentoTimeLSB', 32 + 5],
    ['DataEntryLSB', 32 + 6],
    ['ChannelVolumeLSB', 32 + 7],
    ['PanLSB', 32 + 10],
    ['ExpressioLSB', 32 + 11],
    ['Hold1', 64],
    ['PortamentoOnOff', 65],
    ['Sostenuto', 66],
    ['Soft', 67],
    ['FilterResonance', 71],
    ['ReleaseTime', 72],
    ['AttackTime', 73],
    ['Brightness', 74],
    ['DecayTime', 75],
    ['VibratoRate', 76],
    ['VibratoDepth', 77],
    ['VibratoDelay', 78],
    ['ReverbSendLevel', 91],
    ['ChorusSendLevel', 93],
    ['RPNLSB', 100],
    ['RPNMSB', 101]
  ].each do |name, num|
    module_eval <<-"end;"
      class #{name} < ControlChange

	def initialize(offset, ch, val)
	  # val:0/2**7-1
	  super(offset, ch, #{num}, val)
	end

      end
    end;
  end

  [ ['PitchBendSensitivity', 0, 0],
    ['ChannelFineTune', 1, 0],
    ['ChannelCoarseTune', 2, 0],
    ['ModulationDepthRange', 5, 0],
    ['RPNNULL', 0x7f, 0x7f]
  ].each do |name, lsb, msb|
    module_eval <<-"end;"
      class #{name}LSB < RPNLSB

	def initialize(offset, ch)
	  super(offset, ch, #{lsb})
	end

      end

      class #{name}MSB < RPNMSB

	def initialize(offset, ch)
	  super(offset, ch, #{msb})
	end

      end
    end;
  end

  class MasterVolume < ExclusiveF0

    def initialize(offset, vol, dev=0x7f)
      # vol:0/2**14-1
      vl =  vol       & 0x7f
      vm = (vol >> 7) & 0x7f
      super(offset, [0x7f, dev, 0x04, 0x01, vl, vm, 0xf7].pack('C*'))
    end

  end

  class MasterFineTuning < ExclusiveF0

    def initialize(offset, val, dev=0x7f)
      # val:-2**13/2**13-1
      val += 0x2000
      fl =  val       & 0x7f
      fm = (val >> 7) & 0x7f
      super(offset, [0x7f, dev, 0x04, 0x03, fl, fm, 0xf7].pack('C*'))
    end

  end

  class MasterCoarseTuning < ExclusiveF0

    def initialize(offset, cc, dev=0x7f)
      # cc:0/2**7-1
      super(offset, [0x7f, dev, 0x04, 0x04, 0, cc, 0xf7].pack('C*'))
    end

  end

  class ReverbParameter < ExclusiveF0

    def initialize(offset, pp, vv, dev=0x7f)
      # pp:0/1, vv:0/8
      super(offset, [0x7f, dev, 0x04, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01,
	      pp, vv, 0xf7].pack('C*'))
    end

  end

  class ReverbType < ReverbParameter

    def initialize(offset, vv, dev=0x7f)
      # vv:0/8
      super(offset, 0, vv, dev)
    end

  end

  class ReverbTime < ReverbParameter

    def initialize(offset, vv, dev=0x7f)
      # vv:0/8
      super(offset, 1, vv, dev)
    end

  end

  class ChorusParameter < ExclusiveF0

    def initialize(offset, pp, vv, dev=0x7f)
      # pp:0/4, vv:0/2**7-1
      super(offset, [0x7f, dev, 0x04, 0x05, 0x01, 0x01, 0x01, 0x01, 0x02,
	      pp, vv, 0xf7].pack('C*'))
    end

  end

  class ChorusType < ChorusParameter

    def initialize(offset, vv, dev=0x7f)
      # vv:0/5
      super(offset, 0, vv, dev)
    end

  end

  class ChorusModRate < ChorusParameter

    def initialize(offset, vv, dev=0x7f)
      super(offset, 1, vv, dev)
    end

  end

  class ChorusModDepth < ChorusParameter

    def initialize(offset, vv, dev=0x7f)
      # vv:0/2**7-1
      super(offset, 2, vv, dev)
    end

  end

  class ChorusFeedback < ChorusParameter

    def initialize(offset, vv, dev=0x7f)
      # vv:0/2**7-1
      super(offset, 3, vv, dev)
    end

  end

  class ChorusSendToReverb < ChorusParameter

    def initialize(offset, vv, dev=0x7f)
      # vv:0/2**7-1
      super(offset, 4, vv, dev)
    end

  end

  class ControllerDestinationSetting < ExclusiveF0

    def initialize(offset, id2, ch, pp_rr, dev=0x7f)
      # id2:1|3, ch:0/15, pp:0/5, rr:0/2**7-1
      super(offset, [0x7f, dev, 0x09, id2, ch, pp_rr, 0xf7].
	      flatten.pack('C*'))
    end

  end

  class CDSChannelPressure < ControllerDestinationSetting

    def initialize(offset, ch, pp_rr, dev=0x7f)
      # pp:0/5, rr:0/2**7-1
      super(0x01, ch, pp_rr, dev)
    end

  end

  class CDSControlChange < ControllerDestinationSetting

    def initialize(offset, ch, pp_rr, dev=0x7f)
      # pp:0/5, rr:0/2**7-1
      super(0x03, ch, pp_rr, dev)
    end

  end

  class ScaleTuningAdjust1ByteFormRealTime < ExclusiveF0

    def initialize(offset, ch, ss, dev=0x7f)
      # ch:0/2**16-1, ss:-2**6/2**6-1
      ff = ch & 0x3
      gg = (ch >> 2) & 0x7f
      hh = (ch >> 9) & 0x7f
      ss.collect! do |x|
	x + 0x40
      end
      super(offset, [0x7f, dev, 0x08, 0x08, ff, gg, hh, ss, 0xf7].
	      flatten.pack('C*'))
    end

  end

  class ScaleTuningAdjust1ByteFormNonRealTime < ExclusiveF0

    def initialize(offset, ch, ss, dev=0x7f)
      # ch:0/2**16-1, ss:-2**6/2**6-1
      ff = ch & 0x3
      gg = (ch >> 2) & 0x7f
      hh = (ch >> 9) & 0x7f
      ss.collect! do |x|
	x + 0x40
      end
      super(offset, [0x7e, dev, 0x08, 0x08, ff, gg, hh, ss, 0xf7].
	      flatten.pack('C*'))
    end

  end

  class ScaleTuningAdjust2ByteFormRealTime < ExclusiveF0

    def initialize(offset, ch, ss_tt, dev=0x7f)
      # ch:0/2**16-1, ss_tt:-2**13/2**13-1
      ff = ch & 0x3
      gg = (ch >> 2) & 0x7f
      hh = (ch >> 9) & 0x7f
      ss_tt.collect! do |x|
	x += 0x2000
	ss =  x       & 0x7f
	tt = (x >> 7) & 0x7f
	[ss, tt]
      end
      super(offset, [0x7f, dev, 0x08, 0x09, ff, gg, hh, ss_tt, 0xf7].
	      flatten.pack('C*'))
    end

  end

  class ScaleTuningAdjust2ByteFormNonRealTime < ExclusiveF0

    def initialize(offset, ch, ss_tt, dev=0x7f)
      # ch:0/2**16-1, ss_tt:-2**13/2**13-1
      ff = ch & 0x3
      gg = (ch >> 2) & 0x7f
      hh = (ch >> 9) & 0x7f
      ss_tt.collect! do |x|
	x += 0x2000
	ss =  x       & 0x7f
	tt = (x >> 7) & 0x7f
	[ss, tt]
      end
      super(offset, [0x7e, dev, 0x08, 0x09, ff, gg, hh, ss_tt, 0xf7].
	      flatten.pack('C*'))
    end

  end

  OctaveTuningAdjust1ByteFormRealTime = ScaleTuningAdjust1ByteFormRealTime
  OctaveTuningAdjust1ByteFormNonRealTime = ScaleTuningAdjust1ByteFormNonRealTime
  OctaveTuningAdjust2ByteFormRealTime = ScaleTuningAdjust2ByteFormRealTime
  OctaveTuningAdjust2ByteFormNonRealTime = ScaleTuningAdjust2ByteFormNonRealTime

  class KeyBasedInstrumentControllers < ExclusiveF0

    def initialize(offset, ch, kk, nn_vv, dev=0x7f)
      # kk:0/2**7-1, nn:7|10|91|93, vv:0/2**7-1
      super(offset, [0x7f, dev, 0x0a, 0x01, ch, kk, nn_vv, 0xf7].
	      flatten.pack('C*'))
    end

  end

  class GM1SystemOn < ExclusiveF0

    def initialize(offset, dev=0x7f)
      super(offset, [0x7e, dev, 0x09, 0x01, 0xf7].pack('C*'))
    end

  end

  GMSystemOn = GM1SystemOn

  class GMSystemOff < ExclusiveF0

    def initialize(offset, dev=0x7f)
      super(offset, [0x7e, dev, 0x09, 0x02, 0xf7].pack('C*'))
    end

  end

  class GM2SystemOn < ExclusiveF0

    def initialize(offset, dev=0x7f)
      super(offset, [0x7e, dev, 0x09, 0x03, 0xf7].pack('C*'))
    end

  end

end
