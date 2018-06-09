module Elite::Actions
  class Brew < Action
    ACTION_NAME = "brew"

    argument name : String
    argument state : Symbol, choices: [:present, :latest, :absent], default: :present
    argument options : Array(String), optional: true

    def process
      # puts "Installing Homebrew package #{@name}"
    end
  end
end
