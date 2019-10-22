#! /usr/bin/ruby
# frozen_string_literal: true

$LOAD_PATH.unshift './lib'

require 'bundler/setup'
require 'socket'
require 'inifile'

require 'lxp/packet'

include LXP::Packet::RegisterBits

config = IniFile.load('config.ini')

# pkt = LXP::Packet::ReadHold.new
# pkt.register = LXP::Packet::Registers::DISCHG_CUT_OFF_SOC_EOD

pkt = LXP::Packet::WriteSingle.new
cmd = ARGV.shift
case cmd
when 'discharge_power'
  pkt.register = LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD
when 'cutoff'
  pkt.register = LXP::Packet::Registers::DISCHG_CUT_OFF_SOC_EOD
else
  puts 'Unknown command'
  exit 1
end

pkt.value = ARGV.shift.to_i

# how to set register 21..
# pkt.register = 21
# pkt.value = R21_DEFAULTS # | AC_CHARGE_ENABLE

pkt.datalog_serial = config['datalog']['serial'].to_s
pkt.inverter_serial = config['inverter']['serial'].to_s

ss = TCPSocket.new(config['inverter']['address'], config['inverter']['port'])
ss.write(pkt.to_bin)
input = ss.recvfrom(2000)[0]

r = LXP::Packet::Parser.parse(input)
p r.value
