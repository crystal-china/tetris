require "pixelfaucet"
require "./sqare"
require "./shape"
require "./fallingblocks"
require "./gamestate"

SCALE = 16
WIDTH = 12
HEIGHT = 25

FallingBlocks.new((WIDTH + 5) * SCALE, HEIGHT * SCALE, 2).run!
