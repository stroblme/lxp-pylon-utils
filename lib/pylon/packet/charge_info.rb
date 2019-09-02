# frozen_string_literal: true

require_relative 'base'

class Pylon
  class Packet
    class ChargeInfo < Base
      def initialize
        super

        # info has a single command byte
        self.len = 0x02

        self.cid2 = 0x92
      end

      # Given a string read directly from RS485, return a hash of data
      def self.parse(ascii)
        i = super # populate i.header and i.info, verify checksum etc.

        packs = i.info[0]

        o = 1

        packs.times.map do
          charge_voltage_limit = int(i.info[o, 2])
          discharge_voltage_limit = int(i.info[o + 2, 2])
          charge_current_limit = int(i.info[o + 4, 2])
          discharge_current_limit = int(i.info[o + 6, 2])
          charge_status = i.info[o + 8]

          o += 9

          {
            charge_voltage_limit: charge_voltage_limit,
            discharge_voltage_limit: discharge_voltage_limit,
            charge_current_limit: charge_current_limit,
            discharge_current_limit: discharge_current_limit,
            charge_status_bits: format('%08b', charge_status),
            charge_status: charge_status
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
