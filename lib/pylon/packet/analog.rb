# frozen_string_literal: true

require_relative 'base'

# pkt = Pylon::Packet::Analog.new
# # pkt.command = 0xFF # all units
# # pkt.to_ascii

class Pylon
  class Packet
    class Analog < Base
      def initialize
        super

        # info has a single command byte
        self.len = 0x02

        self.cid2 = 0x42
      end

      # Given a string read directly from RS485, return a hash of data
      def self.parse(ascii)
        i = super # populate i.header and i.info, verify checksum etc.

        # dunno whats at position 0 yet?
        packs = i.info[1]

        o = 2

        packs.times.map do
          voltages = []
          c = i.info[o]
          o += 1
          c.times do
            voltages << int(i.info[o, 2]) / 1000.0
            o += 2
          end

          temps = []
          c = i.info[o]
          o += 1
          c.times do
            temps << (int_complement(i.info[o, 2]) - 2731) / 10.0
            o += 2
          end

          # transmitted as mA / 100, so / 10 to get Amps
          current = int_complement(i.info[o, 2]) / 10.0
          pack_voltage = int(i.info[o + 2, 2]) / 1000.0
          mah_remain = int(i.info[o + 4, 2])
          # i.info[o+6] # always 2 ?
          mah_total = int(i.info[o + 7, 2])
          pack_cycles = int(i.info[o + 9, 2])

          o += 11

          {
            voltages: voltages,
            temps: temps,
            current: current,
            pack_voltage: pack_voltage,
            mah_remain: mah_remain,
            mah_total: mah_total,
            pack_cycles: pack_cycles
          }
        end
      end

      def command
        @info[0]
      end

      def command=(command)
        @info[0] = command
      end
    end
  end
end
