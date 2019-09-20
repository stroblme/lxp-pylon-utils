#! /usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift 'lib'

require 'bundler/setup'

require 'lxp/packet'
require 'socket'
require 'json'
require 'roda'
require 'inifile'
require 'influxdb'

JSON_FILE = '/tmp/lxp_data.json'
JSON_DATA = File.exist?(JSON_FILE) ? File.read(JSON_FILE) : String.new

CONFIG = IniFile.load('config.ini')

class Web < Roda
  route do |r|
    r.get do
      JSON_DATA
    end
  end
end

def update_influx(data)
  influx = InfluxDB::Client.new CONFIG['influx']['database'],
                                host: CONFIG['influx']['host']

  influx.write_point 'lxp_inverter',
                     values: { v_bat: data[:v_bat], soc: data[:soc],
                               t_inner: data[:t_inner],
                               t_rad_1: data[:t_rad_1],
                               t_rad_2: data[:t_rad_2] }
end

s = TCPSocket.new(CONFIG['inverter']['address'], CONFIG['inverter']['port'])
s.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
s.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPIDLE, 50)
s.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPINTVL, 10)
s.setsockopt(Socket::SOL_TCP, Socket::TCP_KEEPCNT, 5)

output = nil # setup scope

Thread.new do
  Rack::Server.start(Host: '0.0.0.0', Port: 8081, app: Web)
end

loop do
  parser = LXP::Packet::Parser.new(s.recvfrom(2000)[0])
  pkt = parser.parse

  case pkt
  when LXP::Packet::ReadInput1
    # first packet starts a new hash
    output = pkt.to_h
  when LXP::Packet::ReadInput2
    # second packet merges in
    output.merge!(pkt.to_h)
  when LXP::Packet::ReadInput3
    # final packet merges in and saves the result
    output.merge!(pkt.to_h)
    JSON_DATA.replace(JSON.generate(output))
    File.write(JSON_FILE, JSON_DATA)
    update_influx(output)
  end
end

s.close
