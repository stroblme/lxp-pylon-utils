#! /usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift 'lib'

require 'bundler/setup'

require 'lxp'
require 'socket'
require 'json'
require 'roda'

JSON_FILE = '/tmp/lxp_data.json'
class Web < Roda
  route do |r|
    r.get do
      File.read(JSON_FILE)
    end
  end
end

ss = UDPSocket.new
ss.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
ss.bind('255.255.255.255', 4346)

lxp = LXP.new

keys = %i[
  status
  soc v_bat
  v_bus1 v_bus2
  t_inner t_rad1 t_rad2
  max_chg_curr max_dischg_curr
  bat_status0 bat_status1 bat_status2 bat_status3
  bat_status4 bat_status5 bat_status6 bat_status7
  bat_status8 bat_status9 bat_status_inv
]

Thread.new do
  Rack::Server.start(Host: '0.0.0.0', Port: 8081, app: Web)
end

loop do
  data = ss.recvfrom(2000)[0]
  lxp.decode(data)

  next unless lxp.populated

  puts "#{Time.now} #{lxp.soc}% #{lxp.v_bat}V"

  h = keys.map { |k| [k, lxp.send(k)] }.to_h

  # avoid writing bad data (can happen, we don't verify checksums)
  next if h[:v_bat] > 60
  next if h[:t_inner] > 100

  File.write(JSON_FILE, JSON.generate(h))
end

ss.close
