struct Square
  include PF2d
  property color : PF::RGBA

  def initialize(@color : PF::RGBA)
  end

  def draw_to(canvas : Canvas(PF::RGBA), at : Rect)
    canvas.fill_rect(at, color)

    canvas.draw_line(at.top_edge, color.lighten(0.3))
    canvas.draw_line(at.left_edge, color.lighten(0.3))

    canvas.draw_line(at.bottom_edge, color.darken(0.3))
    canvas.draw_line(at.right_edge, color.darken(0.3))
  end
end