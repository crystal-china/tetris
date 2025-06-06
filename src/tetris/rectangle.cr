class Rectangle
  @rect : SDL::Rect
  @original_color : SDL::Color

  def initialize(@width : Int32, @height : Int32, @color : SDL::Color, @renderer : SDL::Renderer, @x = 0, @y = 0)
    @rect = SDL::Rect[@x, @y, @width, @height]
    @original_color = @renderer.draw_color
  end

  def show
    @renderer.draw_color = @color
    @renderer.fill_rect(@rect)
  end

  def hidden
    @renderer.draw_color = @original_color
    @renderer.fill_rect(@rect)
  end
end
