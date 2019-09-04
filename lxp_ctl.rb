#! /usr/bin/ruby
# frozen_string_literal: true

$LOAD_PATH.unshift './lib'

require 'bundler/setup'
require 'socket'
require 'inifile'

require 'lxp/packet'

config = IniFile.load('config.ini')

pkt = LXP::Packet::ReadSingle.new
pkt.register = LXP::Packet::Registers::DISCHG_CUT_OFF_SOC_EOD

# testing random stuff, careful :)
#pkt = LXP::Packet::WriteSingle.new
#pkt.register = 21
##pkt.value = 0b01010100 + (0b11110011 << 8) # register 21
# pkt.discharge_rate = 45
# pkt.discharge_cut_off = 20

pkt.datalog_serial = config['datalog']['serial'].to_s
pkt.inverter_serial = config['inverter']['serial'].to_s

p pkt.bytes

ss = TCPSocket.new(config['inverter']['address'], config['inverter']['port'])
ss.write(pkt.to_bin)
p r = ss.recvfrom(2000)[0]

p LXP::Packet::Base.parse(r)
