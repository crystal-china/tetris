require "ruby2d"

@semaphore = Mutex.new
@field = nil
@prev = nil
@margin = 1
@block_size = 30 + 2 * @margin
@score = nil
@text_score = Text.new @score, x: 5, y: @block_size + 5, z: 1, font: Font.path("PressStart2P-Regular.ttf")
@text_level = Text.new @score, x: 5, y: @block_size + 5, z: 1, font: Font.path("PressStart2P-Regular.ttf")

@row_time = 0
@figure = nil
@x = @y = nil

@paused = false
@pause_rect = Rectangle.new(width: Window.width, height: Window.height, color: [0.5, 0.5, 0.5, 0.75]).tap(&:remove)
@pause_text = Text.new("press 'Space'", z: 1, font: Font.path("PressStart2P-Regular.ttf")).tap(&:remove)
@holding = {}
@pause_text.x = (Window.width - @pause_text.width) / 2
@pause_text.y = (Window.height - @pause_text.height) / 2

def reset_field
  text_highscore = Text.new("", x: 5, y: 5, z: 1, font: Font.path("PressStart2P-Regular.ttf"))
  highscore = if File.exist?("#{Dir.home}/.rbtris")
                File.read("#{Dir.home}/.rbtris").scan(/^1 .*?(\S+)$/).map(&:first).map(&:to_i).max
              else
                "---"
              end

  @field = Array.new(20) { Array.new 10 }
  text_highscore.text = "Highscore: #{highscore}"
end

def mix(f)
  @figure.each_with_index do |row, dy|
    row.each_index do |dx|
      @field[@y + dy][@x + dx] = (row[dx] if f) unless row[dx].zero?
    end
  end
end

@render = lambda do
  reset_field
  w = @block_size * (2 + @field.first.size)
  h = @block_size * (3 + @field.size)
  set width: w, height: h, title: "rbTris"

  Rectangle.new(
    width: w,
    height: h,
    color: "gray"
  )

  Rectangle.new(
    width: w - 2 * @block_size,
    height: h - 3 * @block_size,
    color: "black",
    x: @block_size,
    y: @block_size * 2
  )

  blocks = Array.new(@field.size) do |y|
    Array.new(@field.first.size) do |x|
      [
        Square.new(
          x: @margin + @block_size * (1 + x),
          y: @margin + @block_size * (2 + y),
          size: @block_size - 2 * @margin
        )
      ]
    end
  end

  lambda do
    blocks.each_with_index do |row, i|
      row.each_with_index do |(block, drawn), j|
        if @field[i][j]
          unless drawn == true
            block.color = %w{aqua yellow green red blue orange purple}[(@field[i][j] || 0) - 1]
            block.add
            row[j][1] = true
          end
        else
          unless drawn == false
            block.remove
            row[j][1] = false
          end
        end
      end
    end
  end
end.call # render end

@collision = lambda do
  @figure.each_with_index.any? do |row, dy|
    row.each_with_index.any? do |a, dx|
      !(
        a.zero? ||
        (0...@field.size).cover?(@y + dy) &&
        (0...@field.first.size).cover?(@x + dx) &&
        !@field[@y + dy][@x + dx]
      )
    end
  end or (
    mix(true)
    @render.call
    mix(false)
    false
  )
end

@init_figure = lambda do
  @figure = %w{070 777 006 666 500 555 440 044 033 330 22 22 1111}.each_slice(2).to_a.sample
  rest = @figure.first.size - @figure.size
  @x, @y, @figure = 3, 0, (
    ["0" * @figure.first.size] * (rest / 2) + @figure +
    ["0" * @figure.first.size] * (rest - rest / 2)
  ).map { |st| st.chars.map(&:to_i) }
  next unless @collision.call

  File.open("#{Dir.home}/.rbtris", "a") do |f|
    str = "#{@text_level.text}   #{@text_score.text}".tap(&method(:puts))
    f.puts "1 #{str}"
  end

  [@pause_rect, @pause_text].each &((@paused ^= true) ? :add : :remove)
  @score = nil
end

@reset = lambda do
  @score, @figure = 0, nil
  reset_field
  @init_figure.call
end

@reset.call

try_move = lambda do |dir|
  @x += dir

  next unless @collision.call

  @x -= dir
end

try_rotate = lambda do
  @figure = @figure.reverse.transpose

  next unless @collision.call

  @figure = @figure.transpose.reverse
end

Window.update do
  current = Time.now
  unless @paused
    @text_score.text = "Score: #{@score}"
    @text_score.x = Window.width - 5 - @text_score.width
  end
  @semaphore.synchronize do
    unless @paused
      level = (((@score / 5 + 0.125) * 2) ** 0.5 - 0.5 + 1e-6).floor  # outside of Mutex score is being accesses by render[]
      @text_level.text = "Level: #{level}"
      @row_time = (0.8 - (level - 1) * 0.007) ** (level - 1)
    end
    @prev ||= current - @row_time
    next unless current >= @prev + @row_time

    @prev += @row_time
    next unless @figure && !@paused

    @y += 1
    next unless @collision.call

    @y -= 1
    # puts "FPS: #{(Window.frames.round - 1) / (current - first_time)}" if Window.frames.round > 1
    mix(true)
    @field.partition(&:all?).tap do |a, b|
      @field = a.map { Array.new @field.first.size } + b
      @score += [0, 1, 3, 5, 8].fetch a.size
    end
    @render.call
    @init_figure.call
  end
end

Window.on :key_down do |event|
  @holding[event.key] = Time.now
  @semaphore.synchronize do
    case event.key
    when "left"  then try_move.call(-1) if @figure && !@paused
    when "right" then try_move.call(+1) if @figure && !@paused
    when "up"    then try_rotate.call  if @figure && !@paused
    when "r"
      @reset.call unless @paused
    when "p", "space"
      [@pause_rect, @pause_text].each &((@paused ^= true) ? :add : :remove)
      @reset.call unless @score
    end
  end
end

Window.on :key_held do |event|
  if !@paused
    @semaphore.synchronize do
      key = event.key
      time_span = Time.now - @holding[key]

      case key
      when "left"  then try_move.call(-1) if @figure &&  time_span >= 0.5
      when "right" then try_move.call(+1) if @figure && time_span >= 0.5
      when "up"    then try_rotate.call  if @figure && time_span >= 0.5
      when "down"
        @y += 1
        @prev = if @collision.call
                  @y -= 1
                  Time.now - @row_time
                else
                  Time.now
                end
      end
    end
  end
end

show
