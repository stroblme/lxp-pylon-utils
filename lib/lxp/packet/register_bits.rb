# frozen_string_literal: true

class LXP
  class Packet
    module RegisterBits
      ###
      ### Register 21, Least Significant Byte
      ###
      AC_CHARGE_ENABLE       = 1 << 7
      GRID_ON_POWER_SS       = 1 << 6
      NEUTRAL_DETECT_ENABLE  = 1 << 5
      ANTI_ISLAND_ENABLE     = 1 << 4
      DRMS_ENABLE            = 1 << 2
      OVF_LOAD_DERATE_ENABLE = 1 << 1
      POWER_BACKUP_ENABLE    = 1 << 0

      ###
      ### Register 21, Most Significant Byte
      ###
      FEED_IN_GRID            = 1 << 7
      DCI_ENABLE              = 1 << 6
      GFCI_ENABLE             = 1 << 5
      CHARGE_PRIORITY         = 1 << 3
      FORCED_DISCHARGE_ENABLE = 1 << 2
      NORMAL_OR_STANDBY       = 1 << 1
      SEAMLESS_EPS_SWITCHIGN  = 1 << 0

      ###
      ### Register 105, Least Significant Byte
      ###
      MICRO_GRID_ENABLE       = 1 << 2
      FAST_ZERO_EXPORT_ENABLE = 1 << 1
    end
  end
end
