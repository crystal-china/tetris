require "./pallet"
require "./shapes"

class Shape < PF2d::Grid(UInt8)
  include PF2d

  PALLET = Pallet::PALLET
  SHAPES = Shapes::SHAPES

  def self.random
    new(*SHAPES.values.sample)
  end

  def self.shape(s : Symbol)
    new(*SHAPES[s])
  end

  property pos : Vec2(Float64)

  def initialize(data, width, height, @pos = Vec[0.0, 0.0])
    super(data, width, height)
  end

  def rotate(&)
    self.data = Slice(UInt8).new(data.size) do |i|
      y, x = i.divmod(@width)
      data[yield(x, y)]
    end
  end

  def rotate_right
    rotate { |x, y| (width - 1 - x) * width + y }
  end

  def rotate_left
    rotate { |x, y| x * width + ((width - 1) - y) }
  end

  def draw_to(canvas : Canvas(PF::RGBA), at : Vec, size : Int32)
    0.upto(width - 1) do |y|
      0.upto(width - 1) do |x|
        c = self[x, y]
        if c > 0
          pos = at + Vec[x, y] * size
          Square.new(PALLET[c - 1]).draw_to(canvas, at: Rect[pos.to_i, Vec[size, size]])
        end
      end
    end
  end
end
