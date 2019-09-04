# frozen_string_literal: true

require_relative 'base'

class LXP
  class Packet
    class WriteSingle < Base
      def initialize
        super

        # write single value
        self.device_function = 6

        self.data_length = 18
      end

      def discharge_rate=(value)
        self.register = Registers::DISCHG_POWER_PERCENT_CMD
        self.value = value
      end

      def discharge_cut_off=(value)
        self.register = Registers::DISCHG_CUT_OFF_SOC_EOD
        self.value = value
      end
    end
  end
end
