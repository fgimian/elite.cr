module Elite::Actions
  class Brew < Action
    ACTION_NAME = "brew"

    def name(name : String)
      @name = name
    end

    def run
      puts "Installing Homebrew package #{@name}"
    end
  end
end
