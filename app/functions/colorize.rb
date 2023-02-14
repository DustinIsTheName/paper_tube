class Colorize

  def self.colorize(text, color_code)
    "#{color_code}#{text}\e[0m"
  end

  def self.red(text)
   self.colorize(text, "\e[31m")
  end
  def self.green(text)
   self.colorize(text, "\e[32m") 
  end
  def self.black(text)
    self.colorize(text, "\e[30m\e[47m")
  end
  def self.cyan(text)
    self.colorize(text, "\e[36m\e[1m")
  end
  def self.magenta(text)
    self.colorize(text, "\e[35m\e[1m")
  end

end