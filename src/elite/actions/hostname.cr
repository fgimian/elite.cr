module Elite::Actions
  class Hostname < Action
    ACTION_NAME = "hostname"

    argument local_host_name : String, optional: true
    argument computer_name : String, optional: true

    def process
      changes_made = false

      # Coonfigure the local host name
      if @local_host_name
        current_local_host_name = run(%w(scutil --get LocalHostName), capture_output: true)
        if @local_host_name != current_local_host_name.output.chomp
          run(["scutil", "--set", "LocalHostName", @local_host_name.as(String)])
          changes_made = true
        end
      end

      # Configure the computer name
      if @computer_name
        current_computer_name = run(%w(scutil --get ComputerName), capture_output: true)
        if @computer_name != current_computer_name.output.chomp
          run(["scutil", "--set", "ComputerName", @computer_name.as(String)])
          changes_made = true
        end
      end

      changes_made ? changed : ok
    end
  end
end
