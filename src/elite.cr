# Actions must be required after the abstract base class is defined and the automater must be
# required after the actions so it can create appropriate methods.
require "./elite/action"
require "./elite/actions/*"
require "./elite/automator"
# Remaining libraries don't define macros and can be required in any order.
require "./elite/ansi"
require "./elite/printer"
require "./elite/state"
require "./elite/utils"
require "./elite/version"

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
