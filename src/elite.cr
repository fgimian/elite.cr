# Actions must be required after the abstract base class is defined and the automater must be
# required after the actions so it can create appropriate methods.
require "./elite/action"
require "./elite/actions/*"
require "./elite/automator"
# Remaining libraries don't define macros and can be required in any order.
require "./elite/printer"
require "./elite/state"
require "./elite/version"
require "./elite/utils/*"

# TODO: Write documentation for `Elite`
module Elite
  # TODO: Put your code here
end

def elite
  automator = Elite::Automator.new

  Signal::INT.trap do
    automator.footer(interrupt: true)
    exit
  end

  automator.header
  begin
    with automator yield
  rescue Elite::ActionError
    # Nothing to do here, just catch the error gracefully
  ensure
    automator.footer
  end
end
