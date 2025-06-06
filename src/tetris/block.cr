class Block
  @rect : SDL::Rect
  # @original_color : SDL::Color
  getter? drawn
  setter color

  def initialize(@x : Int32, @y : Int32, @size : Int32, @renderer : SDL::Renderer, @color : SDL::Color = Color.black)
    @rect = SDL::Rect[@x, @y, @size, @size]
    @drawn = false
    # @original_color = @renderer.draw_color
  end

  def add
    @renderer.draw_color = @color
    @renderer.fill_rect(@rect)
    @drawn = true
  end

  def remove
    @renderer.draw_color = Color.black
    @renderer.fill_rect(@rect)
    @drawn = false
  end
end
