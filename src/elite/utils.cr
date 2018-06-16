module Elite::Utils
  # Workaround: Crystal doesn't appear to provide a way to center text
  def self.center(text : String, width : Int)
    padding = (width.to_f - text.size) / 2
    " " * padding.floor.to_i + text + " " * padding.ceil.to_i
  end
end
