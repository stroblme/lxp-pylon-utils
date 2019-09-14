#! /usr/bin/env ruby
# frozen_string_literal: true

# convert hex input to array of ints:
#
#   str = '20024642E002FFFD09'
#   [str.tr!(' ', '')].pack('H*').unpack('C' * (str.length/2))
#   # => [32, 2, 70, 66, 224, 2, 255, 253, 9]
#

$LOAD_PATH.unshift './lib'

require 'bundler/setup'

require 'rubyserial'
require 'json'
require 'roda'

require 'pylon/packet'

JSON_FILE = '/tmp/pylon_data.json'
JSON_DATA = File.read(JSON_FILE) if File.exist?(JSON_FILE)

class Web < Roda
  route do |r|
    r.get do
      JSON_DATA
    end
  end
end

# start a dead simple webserver
Thread.new do
  Rack::Server.start(Host: '0.0.0.0', Port: 8080, app: Web)
end

def read_until_done(port)
  r = String.new

  e = 0

  loop do
    input = port.read(4096)
    r << input
    break if input[-1] == "\r" # found an EOI, can stop immediately

    if input.empty?
      # give up after reading 10 empty packets (spaced 0.3s apart; 3s)
      e += 1
      break if e > 10

      sleep 0.3 # give the Pylon some time to respond, serial isn't instant
    else
      e = 0
      sleep 0.1
    end
  end

  r
end

port = Serial.new('/dev/ttyUSB0', 1200)
analog = Pylon::Packet::Analog.new
analog.command = 0xFF # all units

alarm = Pylon::Packet::Alarm.new
alarm.command = 0xFF # all units

ci = Pylon::Packet::ChargeInfo.new
ci.command = 0xFF # all units

loop do
  port.read(4096) # empty port of any stale data
  port.write(analog.to_ascii)
  analog_data = read_until_done(port)

  port.read(4096) # empty port of any stale data
  port.write(alarm.to_ascii)
  alarm_data = read_until_done(port)

  port.read(4096) # empty port of any stale data
  port.write(ci.to_ascii)
  ci_data = read_until_done(port)

  begin
    p data = {
      analog: Pylon::Packet::Analog.parse(analog_data),
      alarm: Pylon::Packet::Alarm.parse(alarm_data),
      charge_info: Pylon::Packet::ChargeInfo.parse(ci_data)
    }
    JSON_DATA.replace(JSON.generate(data))
    File.write(JSON_FILE, JSON_DATA)
  rescue StandardError
    # ignore invalid checksums, they do seem to happen occasionally
    nil
  end

  sleep 20
end
