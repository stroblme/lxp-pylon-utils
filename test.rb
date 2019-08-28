# frozen_string_literal: true

$LOAD_PATH.unshift './lib'

require 'rubyserial'
require 'json'
require 'roda'

require 'pylon/packet'

def read_until_done(port)
  r = String.new

  sleep 1
  loop do
    sleep 0.5
    input = port.read(4096)
    break if input.empty?

    r << input
  end

  r
end

def get_analog(port, bytes)
  str = bytes.pack('H*' * bytes.length)
  port.write(str)
  r = read_until_done(port)
end

testpkt = "~2001460091AC11040F0CF80CF90CF90CFA0CFA0CFA0CF80CF90CFA0CFA0CF90CF90CF90CFA0CFB050BAF0B9B0B9B0B9B0B9B0017C29D4C2C02C35000030F0CF80CF90CFA0CF80CF90CF90CF90CF70CF80CF90CF70CF90CF90CF90CF8050BB90B9B0B9B0B9B0B9B0016C290465002C35000030F0CFA0CF80CF70CF90CF90CF80CF90CF80CF70CF80CF90CF80CF90CF70CF6050BB90B910B910B910B910016C28A4A3802C35000030F0CFA0CFB0CFA0CF90CFB0CFA0CFA0CFA0CF90CFA0CF90CFA0CFA0CFA0CFB050BAF0B910B910B910B910016C2A64C2C02C35000039BA5\r"
p Pylon::Packet::Analog.parse(testpkt)

exit

port = Serial.new('/dev/ttyUSB0', 1200)
pkt = Pylon::Packet::Analog.new
pkt.command = 0xFF # all units
port.write(pkt.to_ascii)
r = read_until_done(port)

p Pylon::Packet::Analog.parse(r)
