# frozen_string_literal: true

class LXP
  class Packet
    module Registers
      # System Charge Rate (%)
      CHARGE_POWER_PERCENT_CMD = 64

      # System Discharge Rate (%)
      DISCHG_POWER_PERCENT_CMD = 65

      # AC Charge Enable; 100=on?
      AC_CHARGE_POWER_CMD = 66

      # Discharge cut-off SOC (%)
      DISCHG_CUT_OFF_SOC_EOD = 105
    end
  end
end
