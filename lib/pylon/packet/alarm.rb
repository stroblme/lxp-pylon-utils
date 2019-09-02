# frozen_string_literal: true

require_relative 'base'

# pkt = Pylon::Packet::Alarm.new
# # pkt.command = 0xFF # all units
# # pkt.to_ascii

class Pylon
  class Packet
    class Alarm < Base
      def initialize
        super

        # info has a single command byte
        self.len = 0x02

        self.cid2 = 0x44
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
            voltages << i.info[o]
            o += 1
          end

          temps = []
          c = i.info[o]
          o += 1
          c.times do
            temps << i.info[o]
            o += 1
          end

          charge_current = i.info[o]
          pack_voltage = i.info[o + 1]
          discharge_current = i.info[o + 2]

          status1 = i.info[o + 3]
          status2 = i.info[o + 4]
          status3 = i.info[o + 5]
          status4 = i.info[o + 6]
          status5 = i.info[o + 7]

          o += 8

          {
            voltages: voltages,
            temps: temps,
            charge_current: charge_current,
            pack_voltage: pack_voltage,
            discharge_current: discharge_current,
            status1: status1,
            status1_bits: format('%08b', status1),
            status2: status2,
            status2_bits: format('%08b', status2),
            status3: status3,
            status3_bits: format('%08b', status3),
            status4: status4,
            status4_bits: format('%08b', status4),
            status5: status5,
            status5_bits: format('%08b', status5)
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
