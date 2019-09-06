# frozen_string_literal: true

require 'utils'

require_relative 'device_functions'
require_relative 'tcp_functions'

class LXP
  class Packet
    # Given an input string, work out which type of LXP::Packet it should be,
    # and call .parse on the appropriate class.
    class Parser
      attr_reader :ascii, :bdata

      def initialize(ascii)
        @ascii = ascii
        @bdata = ascii.unpack('C*')
      end

      def parse
        # FIXME: this method has a bit too much knowledge about LXP packets
        # that is duplicated in Packet::Base, but not sure how to fix that
        # without parsing a packet twice.

        case bdata[7] # tcp_function
        when TcpFunctions::HEARTBEAT
        when TcpFunctions::TRANSLATED_DATA then parse_translated_data
        else
          raise "unhandled tcp_function #{tcp_function}"
        end
      end

      def parse_translated_data
        case bdata[21] # device_function
        when DeviceFunctions::READ_HOLD
        when DeviceFunctions::READ_INPUT then parse_input
        else
          raise "unhandled device_function #{device_function}"
        end
      end

      # Input packets are 1-of-3; work out which it is from the register
      def parse_input
        case Utils.int(bdata[32, 2]) # register
        when 0  then ReadInput1.parse(ascii)
        when 40 then ReadInput2.parse(ascii)
        when 80 then ReadInput3.parse(ascii)
        end
      end
    end
  end
end
