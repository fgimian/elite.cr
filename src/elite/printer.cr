require "unixium"

module Elite
  class Printer
    @overlap_lines : Int32 | Nil

    # Tracks the number of lines we must move upwards to overlap text.
    def initialize
      @overlap_lines = nil
    end

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

    # Prints task information within a section using the *name* provided.  This should be
    # followed by a call to #action.
    def task(name : String)
      puts
      puts "#{ANSI::BOLD}#{name}#{ANSI::ENDC}"
      puts
    end

    # TODO: is there a better way to do this?
    private def center(text : String, width : Int)
      padding = (width.to_f - text.size) / 2
      left_padding = padding.floor.to_i
      right_padding = padding.ceil.to_i
      " " * left_padding + text + " " * right_padding
    end

    # Displays a particular task along with the related message upon failure.
    #
    # :param state: The state of the task which is an enum of type EliteStatus.
    # :param action: The action being called.
    # :param args: The arguments sent to the action.
    # :param result: The result of the execution or nil when the task is still running.
    def action(state : Enum, action : String, args : NamedTuple, failed_message : String | Nil = nil)
      # Determine the output colour and state text
      if state == State::Running
        print_colour = ANSI::WHITE
        print_state = "running"
      elsif state == State::Failed
        print_colour = ANSI::RED
        print_state = "failed"
      elsif state == State::Changed
        print_colour = ANSI::YELLOW
        print_state = "changed"
      else
        print_colour = ANSI::GREEN
        print_state = "ok"
      end

      # Prettify arguments and action for printing
      print_args_strs = [] of String
      args.each do |key, value|
        next unless value
        print_args_strs << "#{key}=#{value.inspect}"
      end

      print_args = print_args_strs.any? ? print_args_strs.join(" ") : ""
      print_action = print_args.empty? ? action : "#{action}: "

      # Determine the max characters we can print
      if state == State::Running
        terminal_size = Unixium::Terminal.size
        max_chars = terminal_size.columns * terminal_size.rows

        print_status = ""
        print_chars = 0

        [
          {print_colour, center(print_state, 10)},
          {ANSI::BLUE, print_action},
          {ANSI::YELLOW, print_args}
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
          "#{print_colour}#{center(print_state, 10)}#{ANSI::ENDC}" \
          "#{ANSI::BLUE}#{print_action}#{ANSI::ENDC}" \
          "#{ANSI::YELLOW}#{print_args}#{ANSI::ENDC}"
        )

        # Display the changed or failure message if necessary
        if state == State::Failed && failed_message
          puts(
            "#{ANSI::BLUE}#{center("", 10)}message:#{ANSI::ENDC} " \
            "#{ANSI::YELLOW}#{failed_message}#{ANSI::ENDC}"
          )
        end

        # Reset the number of lines to overlap
        @overlap_lines = nil
      end
    end

    # Displays a final summary after execution of all tasks have completed.
    #
    # :param ok_tasks: A list of tuples containing information relating on successful tasks.
    # :param changed_tasks: A list of tuples containing information relating on each
    #             changes made.
    # :param failed_tasks: A list of tuples containing information relating to each failed task.
    def summary(ok_tasks : Array(Tuple), changed_tasks : Array(Tuple), failed_tasks : Array(Tuple))
      group "Summary"

      # Display any tasks that caused changes.
      if changed_tasks
        task "Changed task info:"
        changed_tasks.each do |action, args, result|
          action State::Changed, action, args, result
        end
      end

      # Display any failed tasks.
      if failed_tasks
        task "Failed task info:"
        failed_tasks.each do |action, args, result|
          action State::Failed, action, args, result
        end
      end

      # Display all totals
      total_tasks = ok_tasks.size + changed_tasks.size + failed_tasks.size
      task "Totals:"
      printf "%s%4d\n", "#{ANSI::GREEN}#{center("ok", 10)}#{ANSI::ENDC}", ok_tasks.size
      printf "%s%4d\n", "#{ANSI::YELLOW}#{center("changed", 10)}#{ANSI::ENDC}", changed_tasks.size
      printf "%s%4d\n", "#{ANSI::RED}#{center("failed", 10)}#{ANSI::ENDC}", failed_tasks.size
      printf "%s%4d\n", center("total", 10), total_tasks
    end
  end
end
