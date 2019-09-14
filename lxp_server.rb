#! /usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift 'lib'

require 'bundler/setup'

require 'lxp/packet'
require 'socket'
require 'json'
require 'roda'
require 'inifile'

JSON_FILE = '/tmp/lxp_data.json'
JSON_DATA = File.read(JSON_FILE) if File.exist?(JSON_FILE)

class Web < Roda
  route do |r|
    r.get do
      JSON_DATA
    end
  end
end

config = IniFile.load('config.ini')
s = TCPSocket.new(config['inverter']['address'], config['inverter']['port'])
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
  end
end

s.close
