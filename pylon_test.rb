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

def read_until_done(port)
  r = String.new

  e = 0

  loop do
    input = port.read(4096)
    r << input

    break if input[-1] == "\r" # found an EOI, can stop immediately

    e += 1 if input.empty?
    break if e > 5

    sleep 0.3 # give the Pylon some time to respond, serial isn't instant
  end

  r
end

port = Serial.new('/dev/ttyUSB0', 115_200)
analog = Pylon::Packet::Alarm.new
analog.command = 0xFF # all units

port.write(analog.to_ascii)
r = read_until_done(port)

#r = "~20024600D0F400040F010101010101010101010101010101050000000000000000020E4000000F000000000000000000000000000000050000000000000000000E4000000F000000000000000000000000000000050000000000000000000E4000000F000000000000000000000000000000050000000000000000000E400000CEDF\r"
p Pylon::Packet::Alarm.parse(r)

