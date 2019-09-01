#! /usr/bin/ruby
# frozen_string_literal: true

# quick reference on munging data packets :)
#
# bytes = "~20004642E00200FD37\r".bytes.map { |n| sprintf("%02X", n) }
# => ["7E", "32", "30", "30", "30", "34", "36", "34", "32", "45", "30", "30", "32", "30", "30", "46", "44", "33", "37", "0D"]
#
# and..
#
# str = bytes.pack('H*' * bytes.length)
# => => "~20004642E00200FD37\r"
#
# can be useful to get actual ints. this only works if you cut off SOI and EOI
#
#   str = '20024642E002FFFD09'
#   [str].pack('H*').unpack('C' * (str.length/2))
#   # => [32, 2, 70, 66, 224, 2, 255, 253, 9]
#

$LOAD_PATH.unshift './lib'

require 'bundler/setup'

require 'rubyserial'
require 'json'
require 'roda'

require 'pylon/packet'

JSON_FILE = '/tmp/pylon_data.json'
class Web < Roda
  route do |r|
    r.get do
      File.read(JSON_FILE)
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

loop do
  port.read(4096) # empty port of any stale data
  port.write(analog.to_ascii)
  analog_data = read_until_done(port)

  port.read(4096) # empty port of any stale data
  port.write(alarm.to_ascii)
  alarm_data = read_until_done(port)

  begin
    p data = {
      analog: Pylon::Packet::Analog.parse(analog_data),
      alarm: Pylon::Packet::Alarm.parse(alarm_data)
    }
    json = JSON.generate(data)
    File.write(JSON_FILE, json)
  rescue StandardError
    # ignore invalid checksums, they do seem to happen occasionally
    nil
  end

  sleep 20
end
