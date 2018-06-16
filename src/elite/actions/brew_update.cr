module Elite::Actions
  class BrewUpdate < Action
    ACTION_NAME = "brew_update"

    def process
      # Obtain information about the requested package
      brew_update_proc = run(%w(brew update), capture_output: true)

      # Determine if any changes were made
      if brew_update_proc.output.chomp == "Already up-to-date."
        ok
      else
        changed
      end
    end
  end
end
