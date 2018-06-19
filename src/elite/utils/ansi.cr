module Elite::ANSI
  # Escape Sequences
  CLEAR_LINE = "\x1b[0K"
  HIDE_CURSOR = "\x1b[?25l"
  SHOW_CURSOR = "\x1b[?25h"

  # Moves the Terminal cursor position up by the #num_lines specified
  def self.move_up(num_lines)
    num_lines && num_lines > 0 ? "\033[{num_lines}A" : ""
  end

  # Moves the Terminal cursor position down by the #num_lines specified
  def self.move_down(num_lines)
    num_lines && num_lines > 0 ? "\033[{num_lines}B" : ""
  end

  # Moves the Terminal cursor position forward by the #num_columns specified
  def self.move_forward(num_columns)
    num_lines && num_columns > 0 ? "\033[{num_columns}C" : ""
  end

  # Moves the Terminal cursor position backward by the #num_columns specified
  def self.move_backward(num_columns)
    num_lines && num_columns > 0 ? "\033[{num_columns}D" : ""
  end
end
