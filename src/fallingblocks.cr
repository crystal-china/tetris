class FallingBlocks < PF::Game
  include PF

  @font : Pixelfont::Font = Pixelfont::Font.new("#{__DIR__}/../lib/pixelfont/fonts/pixel-5x7.txt")
  @field = PF2d::Grid(UInt8).new(WIDTH, HEIGHT) do |p, s|
    p.x == 0 || p.x == s.x - 1 || p.y == s.y - 1 ? 8u8 : 0u8
  end
  @move_target : Vec2(Int32) = Vec[0, 0]
  @fall_speed = 1.0 # Blocks per second
  @move = Interval.new(0.2.seconds)
  @left_repeat = Interval.new(60.milliseconds)
  @right_repeat = Interval.new(60.milliseconds)
  @left_delay = Timeout.new(0.2.seconds)
  @right_delay = Timeout.new(0.2.seconds)
  @state = GameState::Normal
  @line_blink = Interval.new(20.milliseconds)
  @animation_wait = Timeout.new(0.3.seconds)
  @cleared = 0
  @time_to_settle = 0.3.seconds
  @settle = 0.seconds
  @soft_drop_hold_time = 0.0
  @soft_drop_max_speed = 80.0
  @soft_drop_ramp_duration = 0.3

  def initialize(*args, **kwargs)
    super

    @falling = Shape.random
    @next = Array(Shape).new(3) { Shape.random }
    @move.pause
    @left_repeat.pause
    @right_repeat.pause

    keys.map({
      Key::Code::D      => "right",
      Key::Code::Right  => "right",
      Key::Code::A      => "left",
      Key::Code::Left   => "left",
      Key::Code::S      => "soft drop",
      Key::Code::Down   => "soft drop",
      Key::Code::W      => "rotate right",
      Key::Code::Up     => "rotate right",
      Key::Code::Z      => "rotate left",
      Key::Code::X      => "rotate right",
      Key::Code::Space  => "hard drop",
      Key::Code::Escape => "reset",
    })

    new_drop
  end

  def collides?(at : Vec2(Int))
    clip = @field.clip(Rect[at, @falling.size])
    @falling.any? { |(p, v)| v > 0 && clip[p]?.try { |o| o > 0 } }
  end

  def collides?
    collides?(@falling.pos.to_i) ||
      collides?(@falling.pos.to_i + Vec[0, 1])
  end

  def collides_right?
    if @falling.pos.y - @falling.pos.y.floor < 0.25
      collides?(@falling.pos.to_i + Vec[1, 0])
    else
      collides?(@falling.pos.to_i + Vec[1, 0]) ||
        collides?(@falling.pos.to_i + Vec[1, 1])
    end
  end

  def collides_left?
    if @falling.pos.y - @falling.pos.y.floor < 0.25
      collides?(@falling.pos.to_i + Vec[-1, 0])
    else
      collides?(@falling.pos.to_i + Vec[-1, 0]) ||
        collides?(@falling.pos.to_i + Vec[-1, 1])
    end
  end

  def collides_down?
    collides?(@falling.pos.to_i + Vec[0, 1])
  end

  def try_move(dx : Int32)
    return if dx > 0 && collides_right?
    return if dx < 0 && collides_left?
    @falling.pos.x = @falling.pos.x + dx
  end

  # Just jiggle the piece around a bunch, I guess.
  def kick?
    @falling.pos += Vec[1, 0]
    return true unless collides?
    @falling.pos += Vec[-2, 0]
    return true unless collides?
    @falling.pos += Vec[1, -1]
    return true unless collides? # Floor kick
    @falling.pos += Vec[0, 1]
    false
  end

  def lines
    result = [] of Int32
    4.upto(@field.height - 2) do |y|
      line = true
      1.upto(@field.width - 2) do |x|
        if @field[x, y] == 0
          line = false
          break
        end
      end
      result << y if line
    end
    result
  end

  def new_drop
    @settle = @time_to_settle
    @soft_drop_hold_time = 0.0
    @falling = @next.shift
    @next << Shape.random
    @falling.pos = Vec[@field.width / 2 - 1, 0.0]
    @animation_wait.reset
  end

  def update(delta_time)
    ds = delta_time.total_seconds

    if keys["reset"].pressed?
      @cleared = 0
      @field = PF2d::Grid(UInt8).new(WIDTH, HEIGHT) do |p, s|
        p.x == 0 || p.x == s.x - 1 || p.y == s.y - 1 ? 8u8 : 0u8
      end
      @state = GameState::Normal
      new_drop
    end

    case @state
    when GameState::Normal
      if keys["right"].pressed?
        try_move(1)
        @right_delay.reset
        @right_repeat.reset
        @right_repeat.pause
      end

      if keys["right"].held?
        @right_delay.update(delta_time) do
          @right_repeat.resume
        end
        if @right_delay.triggered?
          @right_repeat.update(delta_time) { try_move(1) }
        end
      else
        @right_delay.reset
        @right_repeat.reset
        @right_repeat.pause
      end

      if keys["left"].pressed?
        try_move(-1)
        @left_delay.reset
        @left_repeat.reset
        @left_repeat.pause
      end

      if keys["left"].held?
        @left_delay.update(delta_time) do
          @left_repeat.resume
        end
        if @left_delay.triggered?
          @left_repeat.update(delta_time) { try_move(-1) }
        end
      else
        @left_delay.reset
        @left_repeat.reset
        @left_repeat.pause
      end

      if keys["rotate right"].pressed?
        @falling.rotate_right
        @falling.rotate_left if collides? && !kick?
      end

      if keys["rotate left"].pressed?
        @falling.rotate_left
        @falling.rotate_right if collides? && !kick?
      end

      if keys["hard drop"].pressed?
        @falling.pos.y = @falling.pos.y.to_i.to_f

        until collides_down?
          @falling.pos += Vec[0, 1]
        end
        @settle = 0.seconds
        @soft_drop_hold_time = 0.0
      elsif keys["soft drop"].held?
        @soft_drop_hold_time += ds
        soft_drop_ratio = {@soft_drop_hold_time / @soft_drop_ramp_duration, 1.0}.min
        soft_drop_speed = @soft_drop_max_speed * soft_drop_ratio
        @falling.pos += Vec[0.0, soft_drop_speed] * ds
      else
        @soft_drop_hold_time = 0.0
      end

      if collides_down?
        @falling.pos.y = @falling.pos.y.floor
        @settle -= delta_time
        if @settle.to_f <= 0
          # Stamp the piece ext install GitHub.copilotonto the field
          @field.draw(@falling, @falling.pos.round.to_i) { |src, dst| src + dst }

          if @falling.pos.y < 4
            @state = GameState::GameOver
          else
            new_drop
          end
        end
      else
        @falling.pos += Vec[0.0, @fall_speed + (@cleared // 10)] * ds
      end

      @line_blink.update(delta_time) do
        lines.each do |y|
          c = rand(1u8...Shape::PALLET.size.to_u8)
          1.upto(@field.width - 2) do |x|
            @field[x, y] = c
          end
        end
      end

      @animation_wait.update(delta_time) do
        @state = GameState::Normal
        @cleared += lines.size
        lines.each_with_index do |y, i|
          @field.data[0...(@field.width * (y + 1) - 1)].rotate!(-(@field.width))
          @field.row(0)[1...-1].map! { 0u8 }
          @field[@field.width - 1, 0] = Shape::PALLET.size.to_u8
        end
      end
    when GameState::GameOver
    end
  end

  def frame(delta_time)
    window.draw do
      window.clear(50, 50, 50)

      4.upto(@field.height) do |y|
        window.draw_line(Vec[0, y * SCALE], Vec[SCALE * @field.width, y * SCALE], RGBA[60, 60, 60])
        0.upto(@field.width) do |x|
          window.draw_line(Vec[x * SCALE, 4 * SCALE], Vec[x * SCALE, SCALE * @field.height], RGBA[80, 80, 80])
        end
      end

      @field.each_point do |p|
        if @field[p] > 0
          pos = p * SCALE
          c = @field[p]
          Square.new(Shape::PALLET[(c - 1) % Shape::PALLET.size]).draw_to(window, at: Rect[pos.to_i, Vec[SCALE, SCALE]])
        end
      end

      @next.each_with_index do |shape, i|
        x = @field.width * SCALE + (SCALE // 2)
        y = (i * 4) * SCALE + (i * (SCALE // 2))
        shape.draw_to(window, Vec[x, y], SCALE)
      end

      @falling.draw_to(window, @falling.pos * SCALE, SCALE)
      window.draw_string(<<-TEXT, @field.width * SCALE + SCALE // 2, @next.size * 5 * SCALE + SCALE // 2, @font, PF::Colors::White)
      Lines: #{@cleared}
      TEXT

      if @state.game_over?
        window.draw_string(<<-TEXT, (@field.width * SCALE) // 2 - @font.width_of("Game Over!") // 2, SCALE, @font, PF::Colors::White)
        Game Over!
        TEXT
      end
    end
  end
end
