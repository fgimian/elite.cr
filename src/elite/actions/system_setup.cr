module Elite::Actions
  class SystemSetup < Action
    ACTION_NAME = "system_setup"

    argument timezone : String, optional: true
    argument computer_sleep_time : String, optional: true
    argument display_sleep_time : String, optional: true
    add_arguments

    def process
      changes_made = false

      # Coonfigure the timezone
      if @timezone
        current_timezone = run(%w(systemsetup -gettimezone), capture_output: true)
        if "Time Zone: #{@timezone}" != current_timezone.output.chomp
          run(["systemsetup", "-settimezone", @timezone.as(String)])
          changes_made = true
        end
      end

      # Configure the computer sleep time
      if @computer_sleep_time
        computer_sleep = run(%w(systemsetup -getcomputersleep), capture_output: true)
        if ("Computer Sleep: #{@computer_sleep_time}" !=
            computer_sleep.output.chomp.sub("after ", "").sub(" minutes", ""))
          run(["systemsetup", "-setcomputersleep", @computer_sleep_time.as(String)])
          changes_made = true
        end
      end

      # Configure the display sleep
      if @display_sleep_time
        display_sleep = run(%w(systemsetup -getdisplaysleep), capture_output: true)
        if ("Display Sleep: #{@display_sleep_time}" !=
            display_sleep.output.chomp.sub("after ", "").sub(" minutes", ""))
          run(["systemsetup", "-setdisplaysleep", @display_sleep_time.as(String)])
          changes_made = true
        end
      end

      changes_made ? changed : ok
    end
  end
end
