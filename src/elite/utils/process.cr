require "unixium"

# Overrides various methods in the Process class to add support for switching to a different
# uid and gid after forking a process and before its execution.  This allows for true demotion
# of permissions for processes when a program is running as root.
class Process
  # Executes a process and waits for it to complete.
  #
  # By default the process is configured without input, output or error.
  def self.run(command : String, args = nil, env : Env = nil, clear_env : Bool = false,
               shell : Bool = false, input : Stdio = Redirect::Close,
               output : Stdio = Redirect::Close, error : Stdio = Redirect::Close,
               chdir : String? = nil, uid : UInt32? = nil, gid : UInt32? = nil) : Process::Status
    status = new(command, args, env, clear_env, shell, input, output, error, chdir, uid, gid).wait
    $? = status
    status
  end

  # Executes a process, yields the block, and then waits for it to finish.
  #
  # By default the process is configured to use pipes for input, output and error. These
  # will be closed automatically at the end of the block.
  #
  # Returns the block's value.
  def self.run(command : String, args = nil, env : Env = nil, clear_env : Bool = false,
               shell : Bool = false, input : Stdio = Redirect::Pipe,
               output : Stdio = Redirect::Pipe, error : Stdio = Redirect::Pipe,
               chdir : String? = nil, uid : UInt32? = nil, gid : UInt32? = nil)
    process = new(command, args, env, clear_env, shell, input, output, error, chdir, uid, gid)
    begin
      value = yield process
      $? = process.wait
      value
    rescue ex
      process.kill
      raise ex
    end
  end

  # Creates a process, executes it, but doesn't wait for it to complete.
  #
  # To wait for it to finish, invoke `wait`.
  #
  # By default the process is configured without input, output or error.
  def initialize(command : String, args = nil, env : Env = nil, clear_env : Bool = false,
                 shell : Bool = false, input : Stdio = Redirect::Close,
                 output : Stdio = Redirect::Close, error : Stdio = Redirect::Close,
                 chdir : String? = nil, uid : UInt32? = nil, gid : UInt32? = nil)
    command, argv = Process.prepare_argv(command, args, shell)

    @wait_count = 0

    if needs_pipe?(input)
      fork_input, process_input = IO.pipe(read_blocking: true)
      if input.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(input, process_input, channel, close_dst: true) }
      else
        @input = process_input
      end
    end

    if needs_pipe?(output)
      process_output, fork_output = IO.pipe(write_blocking: true)
      if output.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(process_output, output, channel, close_src: true) }
      else
        @output = process_output
      end
    end

    if needs_pipe?(error)
      process_error, fork_error = IO.pipe(write_blocking: true)
      if error.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(process_error, error, channel, close_src: true) }
      else
        @error = process_error
      end
    end

    @pid = Process.fork_internal(run_hooks: false) do
      # Reduce user permissions for the newly forked process if necessary
      if gid.is_a?(UInt32) || uid.is_a?(UInt32)
        egid = Unixium::Permissions.egid
        euid = Unixium::Permissions.euid

        Unixium::Permissions.egid(0_u32)
        Unixium::Permissions.euid(0_u32)
        Unixium::Permissions.gid(gid) if gid.is_a?(UInt32)
        Unixium::Permissions.uid(uid) if uid.is_a?(UInt32)
        Unixium::Permissions.egid(egid)
        Unixium::Permissions.euid(euid)
      end

      begin
        Process.exec_internal(
          command,
          argv,
          env,
          clear_env,
          fork_input || input,
          fork_output || output,
          fork_error || error,
          chdir
        )
      rescue ex
        ex.inspect_with_backtrace STDERR
      ensure
        LibC._exit 127
      end
    end

    @waitpid = Crystal::SignalChildHandler.wait(pid)

    fork_input.try &.close
    fork_output.try &.close
    fork_error.try &.close
  end
end
