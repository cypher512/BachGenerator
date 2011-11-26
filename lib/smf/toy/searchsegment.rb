# searchsegment.rb: Written by Tadayoshi Funaba 2006
# $Id: searchsegment.rb,v 1.1 2006-06-20 22:24:14+09 tadf Exp $

module SMF

  module SearchSegment

    def search_segment(a)
      l = 0
      u = a.size
      while l < u
	m = ((l + u) / 2).truncate
	if (yield a[m]) <= 0
	  l = m + 1
	else
	  u = m
	end
      end
      l - 1
    end

  end

end
