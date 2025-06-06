struct Color
  def self.aqua(op = 1.0)
    SDL::Color[0, 255, 255, op*255]
  end

  def self.yellow(op = 1.0)
    SDL::Color[255, 255, 0, op*255]
  end

  def self.green(op = 1.0)
    SDL::Color[0, 128, 0, op*255]
  end

  def self.red(op = 1.0)
    SDL::Color[255, 0, 0, op*255]
  end

  def self.blue(op = 1.0)
    SDL::Color[0, 0, 255, op*255]
  end

  def self.orange(op = 1.0)
    SDL::Color[255, 165, 0, op*255]
  end

  def self.purple(op = 1.0)
    SDL::Color[128, 0, 128, op*255]
  end

  def self.gray(op = 1.0)
    SDL::Color[128, 128, 128, op*255]
  end

  def self.white(op = 1.0)
    SDL::Color[255, 255, 255, op*255]
  end

  def self.black(op = 1.0)
    SDL::Color[0, 0, 0, op*255]
  end
end
