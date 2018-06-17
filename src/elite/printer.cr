require "colorize"
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
      puts name.colorize.bold.underline
    end

    # Prints task information within a group using the *name* provided.  This should be
    # followed by a call to #action.
    def task(name : String)
      puts
      puts name.colorize.bold
      puts
    end

    def state_colour(state)
      case state
      when State::Running then :white
      when State::Failed  then :light_red
      when State::Changed then :light_yellow
      when State::OK      then :light_green
      else                     :white
      end
    end

    # Displays a particular action along with the related message upon failure.
    def action(action : Action, response : ActionResponse?)
      # Determine the state
      state = response ? response.as(ActionResponse).state : State::Running

      # Determine the state text and output colour
      print_state = state.to_s.downcase
      print_colour = state_colour(state)

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
          {:light_blue, print_action},
          {:light_yellow, print_arguments}
        ].each do |colour, text|
          print_chars += text.size

          # We have reached the maximum characters possible to print in the terminal so we
          # crop the text and stop processing further text.
          if print_chars > max_chars
            chop_chars = print_chars - max_chars + 3
            print_status += "#{text[0...-chop_chars]}...".colorize(colour).to_s
            break
          else
            print_status += text.colorize(colour).to_s
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
          "#{Utils.center(print_state, 10).colorize(print_colour)}" \
          "#{print_action.colorize.light_blue}" \
          "#{print_arguments.colorize.light_yellow}"
        )

        # Display the failure message if necessary
        if state == State::Failed && response
          message = response.as(ActionResponse).data.as(ErrorData).message
          puts(
            "#{Utils.center("", 10)}" \
            "#{"message: ".colorize.light_blue}" \
            "#{message.colorize.light_yellow}"
          )
        end

        # Reset the number of lines to overlap
        @overlap_lines = nil
      end

      nil
    end

    def interrupt
      puts
    end

    def total(number : Int32, state : State? = nil)
      print_state = state ? state.to_s.downcase : "total"
      print_colour = state_colour(state)

      printf "%s%4d\n", Utils.center(print_state, 10).colorize(print_colour), number
    end
  end
end
