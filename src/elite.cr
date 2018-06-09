require "./elite/*"

# TODO: Write documentation for `Elite`
module Elite
  # TODO: Put your code here
end

def elite
  automator = Elite::Automator.new
  automator.header
  with automator yield
  automator.footer
end
