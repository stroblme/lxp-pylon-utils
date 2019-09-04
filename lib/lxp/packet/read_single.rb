# frozen_string_literal: true

require_relative 'base'

class LXP
  class Packet
    # ReadHold = Read Holding Value?
    # not sure what ReadInput does..
    class ReadSingle < Base
      def initialize
        super

        # read hold
        self.device_function = 3

        self.data_length = 18

        # seems to be necessary to get the value in the reply..
        self.value = 1
      end
    end
  end
end
