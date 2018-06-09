module Elite::ANSI
  # Text Styles
  BOLD = "\x1b[1m"
  ITALIC = "\x1b[3m"
  UNDERLINE = "\x1b[4m"

  # Bright Colours
  RED = "\x1b[91m"
  GREEN = "\x1b[92m"
  YELLOW = "\x1b[93m"
  BLUE = "\x1b[94m"
  PURPLE = "\x1b[95m"
  CYAN = "\x1b[96m"
  WHITE = "\x1b[97m"
  ENDC = "\x1b[0m"

  # Other Escape Sequences
  CLEAR_LINE = "\x1b[0K"
  HIDE_CURSOR = "\x1b[?25l"
  SHOW_CURSOR = "\x1b[?25h"

  # Moves the Terminal cursor position up by the #num_lines specified
  def self.move_up(num_lines)
    !num_lines.nil? && num_lines > 0 ? "\033[{num_lines}A" : ""
  end

  # Moves the Terminal cursor position down by the #num_lines specified
  def self.move_down(num_lines)
    !num_lines.nil? && num_lines > 0 ? "\033[{num_lines}B" : ""
  end

  # Moves the Terminal cursor position forward by the #num_columns specified
  def self.move_forward(num_columns)
    !num_lines.nil? && num_columns > 0 ? "\033[{num_columns}C" : ""
  end

  # Moves the Terminal cursor position backward by the #num_columns specified
  def self.move_backward(num_columns)
    !num_lines.nil? && num_columns > 0 ? "\033[{num_columns}D" : ""
  end
end
