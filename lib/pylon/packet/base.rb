# frozen_string_literal: true

class Pylon
  # Generate and parse packets to talk to a Pylontech battery unit
  class Packet
    class Base
      attr_accessor :header, :info, :chksum

      def initialize
        @header = [0] * 6
        @info = []
        @chksum = [0, 0]

        # set some defaults
        self.ver = 0x20
        self.adr = 0x02 # default for RS485
        self.cid1 = 0x46 # cid1 is always 0x46 for every packet type
      end

      def to_ascii
        update_checksum

        header_hex = header.map { |n| format('%02X', n) }.join
        info_hex = info.map { |n| format('%02X', n) }.join
        chksum_hex = chksum.map { |n| format('%02X', n) }.join

        hex = [header_hex, info_hex, chksum_hex].join
        "~#{hex}\r"
      end

      # Given a string read directly from RS485, populate instance vars
      def self.parse(ascii)
        raise 'invalid packet' if ascii[0].ord != 0x7E || ascii[-1].ord != 0x0D

        content = ascii[1..-2] # strip SOI and EOI

        # array of integers
        bdata = [content].pack('H*').unpack('C' * (content.length / 2))

        i = new
        6.times { |n| i.header[n] = bdata[n] }
        i.info = bdata[6..-3] if i.len.positive?

        # calculate checksum and compare to input
        i.update_checksum
        raise 'invalid checksum' if i.chksum != bdata[-2..-1]

        i
      end

      def ver
        @header[0]
      end

      def ver=(ver)
        @header[0] = ver
      end

      # adr is 1 for RS232, or 2 for RS485
      def adr
        @header[1]
      end

      def adr=(adr)
        @header[1] = adr
      end

      def cid1
        @header[2]
      end

      def cid1=(cid1)
        @header[2] = cid1
      end

      def cid2
        @header[3]
      end

      def cid2=(cid2)
        @header[3] = cid2
      end

      def len
        ((@header[4] & 0x0F) << 8) | @header[5]
      end

      def len=(len)
        raise 'Invalid len' if len > 0xfff || len.negative?

        sum = (len & 0x000F) + ((len >> 4) & 0x000F) + ((len >> 8) & 0x000F)
        sum = sum % 16
        sum = ~sum
        sum += 1
        val = (sum << 12) + len
        @header[4] = (val >> 8) & 0xff
        @header[5] = (val & 0xff)
      end

      def chksum=(chksum)
        @chksum[0] = (chksum >> 8) & 0xff
        @chksum[1] = chksum & 0xff
      end

      def update_checksum
        sum = 0

        header.map { |n| format('%02X', n) }.join.each_char do |c|
          sum += c.ord
        end
        info.map { |n| format('%02X', n) }.join.each_char do |c|
          sum += c.ord
        end

        sum = sum % 65_536
        sum = ~sum
        sum += 1

        self.chksum = sum
      end

      # Might be better in a Utils module
      def self.int(bytes)
        # everything in this code is most significant byte first,
        # ie [12, 203] becomes 3275 (12 << 8 | 203)
        bytes.reverse.each_with_index.map do |b, idx|
          b << (idx * 8)
        end.inject(:|)
      end
    end
  end
end
