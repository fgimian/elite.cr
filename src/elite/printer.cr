require "unixium"

module Elite
  class Printer
    # Tracks the number of lines we must move upwards to overlap text.
    @overlap_lines : Int32? = nil

    # Prints the master header which hides the cursor.
    def header
      print ANSI::HIDE_CURSOR
      STDOUT.flush
    end

    # Prints the master footer which shows the cursor and prints a new line to end output.
    def footer
      print ANSI::SHOW_CURSOR
      STDOUT.flush
      puts
    end

    # Prints a group heading using the *name* provided.  This should be followed by a call
    # to #task.
    def group(name : String)
      puts
      puts "#{ANSI::BOLD}#{ANSI::UNDERLINE}#{name}#{ANSI::ENDC}"
    end

    # Prints task information within a group using the *name* provided.  This should be
    # followed by a call to #action.
    def task(name : String)
      puts
      puts "#{ANSI::BOLD}#{name}#{ANSI::ENDC}"
      puts
    end

    # Displays a particular action along with the related message upon failure.
    def action(action : Action, response : ActionResponse | Nil)
      # Determine the state
      state = response ? response.as(ActionResponse).state : State::Running

      # Determine the state text and output colour
      print_state = state.to_s.downcase
      print_colour = case state
                     when State::Running then ANSI::WHITE
                     when State::Failed  then ANSI::RED
                     when State::Changed then ANSI::YELLOW
                     else                     ANSI::GREEN # State::OK
                     end

      # Prettify arguments and action for printing
      print_arguments_s = [] of String
      action.arguments.each do |key, value|
        next unless value
        print_arguments_s << "#{key}=#{value.inspect}"
      end

      print_arguments = print_arguments_s.any? ? print_arguments_s.join(" ") : ""
      print_action = print_arguments.empty? ? action.action_name : "#{action.action_name}: "

      # Determine the max characters we can print
      if state == State::Running
        terminal_size = Unixium::Terminal.size
        max_chars = terminal_size.columns * terminal_size.rows

        print_status = ""
        print_chars = 0

        [
          {print_colour, Utils.center(print_state, 10)},
          {ANSI::BLUE, print_action},
          {ANSI::YELLOW, print_arguments}
        ].each do |colour, text|
          print_chars += text.size

          # We have reached the maximum characters possible to print in the terminal so we
          # crop the text and stop processing further text.
          if print_chars > max_chars
            chop_chars = print_chars - max_chars + 3
            print_status += "#{colour}#{text[0...-chop_chars]}...#{ANSI::ENDC}"
            break
          else
            print_status += "#{colour}#{text}#{ANSI::ENDC}"
          end
        end

        print print_status
        STDOUT.flush
        @overlap_lines = (print_chars / terminal_size.columns).ceil - 1
      else
        # Display the current action and its details
        if @overlap_lines
          # Move to the very left of the last line
          print "\r"
          STDOUT.flush
          # Move up to the line we wish to start printing from
          print ANSI.move_up(@overlap_lines)
          STDOUT.flush
        end

        puts(
          "#{print_colour}#{Utils.center(print_state, 10)}#{ANSI::ENDC}" \
          "#{ANSI::BLUE}#{print_action}#{ANSI::ENDC}" \
          "#{ANSI::YELLOW}#{print_arguments}#{ANSI::ENDC}"
        )

        # Display the failure message if necessary
        if state == State::Failed && response
          message = response.as(ActionResponse).data.as(ErrorData).message
          puts(
            "#{ANSI::BLUE}#{Utils.center("", 10)}message:#{ANSI::ENDC} " \
            "#{ANSI::YELLOW}#{message}#{ANSI::ENDC}"
          )
        end

        # Reset the number of lines to overlap
        @overlap_lines = nil
      end

      nil
    end

    # Displays a final summary after execution of all actions have completed.
    def summary(actions_ok : Array(ActionDetails), actions_changed : Array(ActionDetails),
                actions_failed : Array(ActionDetails))
      group "Summary"

      # Display any actions that caused changes.
      task "Changed"
      actions_changed.each do |changed_action|
        action(**changed_action)
      end

      # Display any failed actions.
      task "Failed"
      actions_failed.each do |failed_action|
        action(**failed_action)
      end

      # Display all totals
      total_actions = actions_ok.size + actions_changed.size + actions_failed.size
      task "Totals"
      printf "%s%4d\n", "#{ANSI::GREEN}#{Utils.center("ok", 10)}#{ANSI::ENDC}", actions_ok.size
      printf "%s%4d\n", "#{ANSI::YELLOW}#{Utils.center("changed", 10)}#{ANSI::ENDC}", actions_changed.size
      printf "%s%4d\n", "#{ANSI::RED}#{Utils.center("failed", 10)}#{ANSI::ENDC}", actions_failed.size
      printf "%s%4d\n", Utils.center("total", 10), total_actions
    end
  end
end
