module Elite::Actions
  class Run < Action
    ACTION_NAME = "run"

    argument command : Array(String)
    argument working_dir : String, optional: true
    argument shell : Bool, default: false
    argument except : Array(String), optional: true
    argument creates : String, optional: true
    argument removes : String, optional: true
    add_arguments

    def process
      # Check if the created or removed file is already present
      if @creates
        creates = File.expand_path(@creates.as(String))
        return ok if File.exists?(creates)
      end

      if @removes
        removes = File.expand_path(@removes.as(String))
        return ok unless File.exists?(removes)
      end

      # Check if the optional check command succeeds
      if @except
        except_proc = run(@except.as(Array(String)), ignore_fail: true,
                          shell: @shell.as(Bool), chdir: chdir)
        return ok if except_proc.exit_code == 0
      end

      # Run the given command
      chdir = @working_dir ? File.expand_path(@working_dir.as(String)) : nil
      proc = run(@command.as(Array(String)), capture_output: true, capture_error: true,
                 shell: @shell.as(Bool), chdir: chdir)
      changed(output: proc.output, error: proc.error, exit_code: proc.exit_code)
    end
  end
end
