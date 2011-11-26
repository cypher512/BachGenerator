# rmi.rb: Written by Tadayoshi Funaba 2001-2005
# $Id: rmi.rb,v 1.1 2005-07-09 07:36:31+09 tadf Exp $

module SMF

  module RMI

    def smf2rmi(s)
      pad = s.size % 2
      o =  'RIFF'
      o << [12 + s.size + pad].pack('V')
      o << 'RMID'
      o << 'data'
      o << [s.size].pack('V')
      o << s
      pad.times do o << "\000" end
      o
    end

    def rmi2smf(s)
      x, = s[16,4].unpack('V')
      s[20,x]
    end

    module_function :smf2rmi, :rmi2smf

  end

end
