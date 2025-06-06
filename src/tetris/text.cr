class Text
  getter width : Int32, height : Int32, text : String
  property x, y
  @surface : SDL::Surface

  def initialize(@text : String, @renderer : SDL::Renderer, @x : Int32 = 0, @y : Int32 = 0, @color : SDL::Color = Color.white, @font = FONT)
    @surface = @font.render_shaded(@text, color: @color, background: @renderer.draw_color)
    @width = @surface.width
    @height = @surface.height
  end

  def text=(new_text)
    @text = new_text
    @surface = @font.render_shaded(@text, color: @color, background: @renderer.draw_color)
    @width = @surface.width
    @height = @surface.height
    # refresh
  end

  def show
    @surface = @font.render_shaded(@text, color: @color, background: @renderer.draw_color)
    refresh
  end

  def hidden
    @surface = @font.render_shaded(@text, color: @renderer.draw_color, background: @renderer.draw_color)
    refresh
  end

  private def refresh
    @renderer.copy(@surface, dstrect: SDL::Rect[@x, @y, @surface.width, @surface.height])
  end
end
