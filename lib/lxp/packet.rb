# frozen_string_literal: true

require_relative 'packet/registers'
require_relative 'packet/register_bits'

require_relative 'packet/parser'

# packets from inverter
require_relative 'packet/read_input1'
require_relative 'packet/read_input2'
require_relative 'packet/read_input3'

# packets to inverter
require_relative 'packet/read_single'
require_relative 'packet/write_single'
