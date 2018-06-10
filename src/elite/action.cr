module Elite
  class ActionError < Exception
  end

  class ActionArgumentError < ActionError
  end

  class ActionProcessingError < ActionError
  end

  record ActionResponse, changed : Bool, data = {} of String => String
  record ProcessResponse, exit_code : Int32, output : String, error : String

  abstract class Action
    ACTION_NAME = nil

    ARGUMENT_NAMES = [] of String
    MANDATORY_ARGUMENT_NAMES = [] of String

    macro inherited
      ARGUMENT_NAMES = [] of String
      MANDATORY_ARGUMENT_NAMES = [] of String
    end

    macro argument(name, choices = [] of Symbol, default = nil, optional = false)
      {% unless choices.empty? || default %}
        {% raise "A default is required when choices is used" %}
      {% end %}

      @{{ name.var }} : {{ name.type }} | Nil = {{ default }}

      {% ARGUMENT_NAMES << name.var.stringify %}
      {% MANDATORY_ARGUMENT_NAMES << name.var.stringify unless optional %}

      def {{ name.var }}(value)
        {% unless choices.empty? %}
          unless {{ choices }}.includes?(value)
            choices_s = {{ choices[0...-1].join(", ") }} + " or " + {{ choices[-1] }}
            raise ActionArgumentError.new("{{ name.var }} must be one of #{choices_s}")
          end
        {% end %}

        @{{ name.var }} = value
      end
    end

    macro add_arguments
      def arguments
        {% begin %}
          {% if ARGUMENT_NAMES.empty? %}
            NamedTuple.new
          {% else %}
            {
              {% for argument_name in ARGUMENT_NAMES %}
                {{ argument_name.id }}: @{{ argument_name.id }},
              {% end %}
            }
          {% end %}
        {% end %}
      end
    end

    def invoke
      {% for argument_name in MANDATORY_ARGUMENT_NAMES %}
        unless @{{ argument_name }}
          raise ActionArgumentError.new("argument {{ argument_name }} is mandatory")
        end
      {% end %}

      process
    end

    def ok(data = {} of String => String)
      ActionResponse.new(changed: false, data: data)
    end

    def changed(data = {} of String => String)
      ActionResponse.new(changed: true, data: data)
    end

    # Runs the #command provided and deals with output and errors.
    def run(command : Array(String), capture_output = false, capture_error = false,
            ignore_fail = false, fail_error = nil)
      # Ensure that errors are caught regardless if we intend to report errors
      capture_error = capture_error || !ignore_fail && fail_error.nil?

      # Run the requested process
      process = Process.new(
        command[0], args: command[1..-1],
        output: capture_output ? Process::Redirect::Pipe : Process::Redirect::Close,
        error: capture_error ? Process::Redirect::Pipe : Process::Redirect::Close
      )

      # Capture output if required
      output = capture_output ? process.output.gets_to_end : ""
      error = capture_error ? process.error.gets_to_end : ""

      # Wait for the process to complete
      status = process.wait

      # Process the results
      if status.exit_code > 0 && !ignore_fail
        if !fail_error.nil?
          return ActionError.new(fail_error)
        elsif !error.nil? && error != ""
          # Workaround: Ensure that we handle inexistent executables
          # (see https://github.com/crystal-lang/crystal/issues/3517)
          if status.exit_code == 127
            error = "No such file or directory: #{command[0]}"
          end

          raise ActionProcessingError.new(error.rstrip)
        else
          raise ActionProcessingError.new("Unable to execute command: #{command}")
        end
      end

      return ProcessResponse.new(status.exit_code, output, error)
    end

    def process
      raise NotImplementedError.new("please implement a run method for your action")
    end
  end
end

require "./actions/*"
