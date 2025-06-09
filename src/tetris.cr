require "sdl"
require "sdl/ttf"
require "./tetris/color"
require "./tetris/block"
require "./tetris/rectangle"
require "./tetris/text"

SDL.init(SDL::Init::VIDEO); at_exit { SDL.quit }
SDL::TTF.init; at_exit { SDL::TTF.quit }

FONT = SDL::TTF::Font.new(File.join(__DIR__, "../fonts", "PressStart2P-Regular.ttf"), 28)

class Tetris
  @field : Array(Array(Int32?))
  @prev : Time?
  @figure : Array(Array(Int32))?
  @x : Int32
  @y : Int32
  @blocks : Array(Array(Block))
  @pause_rect : Rectangle
  @text_score : Text

  def initialize
    @field = Array.new(20) { Array(Int32?).new(10, nil) } # --
    @margin = 1                                           # --
    @block_size = 30 + 2 * @margin                        # --
    @row_time = 0.0                                       # --
    @figure = nil                                         # --
    @paused = false                                       # --
    @semaphore = Mutex.new                                # --
    @holding = {} of String => Time                       # --
    @prev = nil                                           # --
    @x = @y = 0                                           # --
    @w = @block_size * (2 + @field.first.size)            # --
    @h = @block_size * (3 + @field.size)                  # --
    @window = SDL::Window.new("Tetris", @w, @h)           # --
    @renderer = SDL::Renderer.new(@window, SDL::Renderer::Flags::ACCELERATED | SDL::Renderer::Flags::PRESENTVSYNC)

    @score = 0 # --
    @text_score = Text.new(@score.to_s, x: 5, y: @block_size + 5, renderer: @renderer)
    @text_level = Text.new(@score.to_s, x: 100, y: @block_size + 5, renderer: @renderer)
    @text_highscore = Text.new("        ", x: 5, y: 5, renderer: @renderer)

    # 画外面的背景色
    @background = Rectangle.new(
      @w,
      @h,
      color: Color.gray,
      renderer: @renderer
    )

    # 游戏区域背景色为黑色
    @play_background = Rectangle.new(
      width: @w - 2 * @block_size,
      height: @h - 3 * @block_size,
      color: Color.black,
      renderer: @renderer,
      x: @block_size,
      y: @block_size*2
    )

    @pause_rect = Rectangle.new(
      width: @w,
      height: @h,
      color: Color.gray(op: 0.75),
      renderer: @renderer
    )
    @pause_text = Text.new(text: "Press 'Space'", renderer: @renderer)
    @pause_text.x = (@w - @pause_text.width) // 2
    @pause_text.y = (@h - @pause_text.height) // 2

    block_size = @block_size - 2 * @margin
    @blocks = Array.new(@field.size) do |y|
      Array.new(@field.first.size) do |x|
        top = @margin + @block_size * (1 + x)
        left = @margin + @block_size * (2 + y)
        Block.new(top, left, block_size, @renderer)
      end
    end

    reset
  end

  def reset
    @score, @figure = 0, nil
    @field = Array.new(20) { Array(Int32?).new(10, nil) }

    highscore = if File.exists?("~/.rbtris")
                  File.read("#{Path.home}/.rbtris")
                    .scan(/1 .*?(\S+)\n/)
                    .map(&.captures.first.not_nil!.to_i)
                    .max
                else
                  "---"
                end

    @text_highscore.text = "Highscore: #{highscore}"

    @field = Array.new(20) { Array(Int32?).new(10, nil) }

    init_figure
  end

  def init_figure
    @x, @y = 3, 0
    figure = %w{070 777 006 666 500 555 440 044 033 330 22 22 1111}.each_slice(2).to_a.sample

    rest = figure.first.size - figure.size

    figure = (
      ["0" * figure.first.size] * (rest // 2) +
      figure +
      ["0" * figure.first.size] * (rest - rest // 2)
    ).map { |st| st.chars.map(&.to_i) }

    @figure = figure

    return unless collision

    File.open("#{Path.home}/.rbtris", "a") do |f|
      str = "#{@text_level.text}   #{@text_score.text}"
      puts str
      f.puts "1 #{str}"
    end

    if (@paused = !@paused)
      [@pause_rect, @pause_text].each(&.show)
    else
      [@pause_rect, @pause_text].each(&.hidden)
    end

    @score = 0
  end

  def collision
    figure = @figure.not_nil!

    figure.each_with_index.any? do |row, dy|
      row.each_with_index.any? do |a, dx|
        !(
          a.zero? ||
            (0...@field.size).includes?(@y + dy) &&
              (0...@field.first.size).includes?(@x + dx) &&
              !@field[@y + dy][@x + dx]
        )
      end
    end || (
      mix(true)
      render_blocks
      mix(false)
      false
    )
  end

  def mix(f)
    figure = @figure.not_nil!

    figure.each_with_index do |row, dy|
      row.each_index do |dx|
        @field[@y + dy][@x + dx] = (row[dx] if f) unless row[dx].zero?
      end
    end
  end

  def render_blocks
    @blocks.each_with_index do |row, i|
      row.each_with_index do |block, j|
        v = @field.dig?(i, j)

        if v
          colors = [
            Color.aqua, Color.yellow, Color.green, Color.red,
            Color.blue, Color.orange, Color.purple,
          ]
          block.color = colors[(v || 0) - 1]
          block.add unless block.drawn?
        else
          block.remove if block.drawn?
        end
      end
    end
  end

  def run(ch1, done)
    next_chan = Channel(Nil).new

    spawn do
      loop do
        sleep 0.005.seconds
        ch1.receive

        @renderer.clear
        @background.show
        @play_background.show

        @renderer.present

        next_chan.send nil
      end
    end

    spawn do
      next_chan.receive

      loop do
        case (event = SDL::Event.poll)
        when SDL::Event::Quit
          break
        when SDL::Event::Keyboard
          break if event.mod.lctrl? && event.sym.q?
        end

        sleep 0.005.seconds
        current = Time.local

        unless @paused
          @text_score.text = "Score: #{@score}"
          @text_score.x = @w - 5 - @text_score.width
        end

        @semaphore.synchronize do
          unless @paused
            # outside of Mutex score is being accesses by render[]
            level = (((@score // 5 + 0.125) * 2) ** 0.5 - 0.5 + 1e-6).floor
            @text_level.text = "Level: #{level}"
            @row_time = (0.8 - (level - 1) * 0.007) ** (level - 1)
          end

          @prev ||= current - @row_time.seconds

          prev = @prev.not_nil!

          next unless current >= prev + @row_time.seconds

          prev += @row_time.seconds

          @prev = prev

          next unless @figure && !@paused

          @y += 1

          next unless collision

          @y -= 1

          mix(true)

          @field.partition(&.all?).tap do |a, b|
            @field = a.map { Array(Int32?).new @field.first.size } + b
            @score += [0, 1, 3, 5, 8][a.size]
          end

          render_blocks
          init_figure
        end

        # @text_score.show
        # @text_level.show
        # @text_highscore.show

        @renderer.present
      end
    end
  end
end

tetris = Tetris.new

ch1 = Channel(Nil).new
done = Channel(Nil).new

tetris.run(ch1, done)

loop { ch1.send nil }

done.receive
