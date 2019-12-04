#! /usr/bin/ruby
# frozen_string_literal: true

$LOAD_PATH.unshift './lib'

require 'bundler/setup'
require 'socket'
require 'inifile'

require 'lxp/packet'

config = IniFile.load('config.ini')

pkt = LXP::Packet::ReadHold.new
# pkt.register = LXP::Packet::Registers::DISCHG_CUT_OFF_SOC_EOD

pkt = LXP::Packet::ReadHold.new
cmd = ARGV.shift
pkt.register = case cmd
               when 'ac_charge'
                 LXP::Packet::Registers::AC_CHARGE_POWER_CMD
               when 'harge_power'
                 LXP::Packet::Registers::CHARGE_POWER_PERCENT_CMD
               when 'discharge_power'
                 LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD
               when 'cutoff'
                 LXP::Packet::Registers::DISCHG_CUT_OFF_SOC_EOD
               else
                 cmd.to_i
               end

# how to set register 21..
# pkt.register = 21
# pkt.value = R21_DEFAULTS # | AC_CHARGE_ENABLE

pkt.datalog_serial = config['datalog']['serial'].to_s
pkt.inverter_serial = config['inverter']['serial'].to_s

ss = TCPSocket.new(config['inverter']['address'], config['inverter']['port'])
ss.write(pkt.to_bin)

r = nil

# wait for the correct reply; ignore heartbeats and other stuff
loop do
  input = ss.recvfrom(2000)[0]
  puts "IN: #{input.unpack('C*')}"
  r = LXP::Packet::Parser.parse(input)
  break if r.is_a?(pkt.class) && r.register == pkt.register
end

puts "Result = #{r.value}"
