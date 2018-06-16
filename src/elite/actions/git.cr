module Elite::Actions
  class Git < Action
    ACTION_NAME = "git"

    argument repo : String
    argument path : String
    argument branch : String, optional: true

    def process
      # Ensure that home directories are taken into account
      path = File.expand_path(@path.as(String))

      # Check if the repository already exists in the destination path
      if File.exists?(File.join([path, ".git", "config"]))
        return ok unless @branch
        branch = @branch.as(String)

        # Verify that the existing repo is on the correct branch
        git_branch_proc = run(
          %w(git symbolic-ref --short HEAD), chdir: path, capture_output: true,
          fail_error: "Unable to check existing repository branch"
        )

        # Currently checked out repo is on the correct branch
        if git_branch_proc.output.chomp == branch
          ok
        # Checked out repo is on the wrong branch and must be switched
        else
          run(
            ["git", "checkout", branch], chdir: path,
            fail_error: "Unable to checkout requested branch"
          )
          changed
        end
      else
        # Build the clone command
        git_command = ["git", "clone", "--quiet"]
        git_command.concat(["-b", @branch.as(String)]) if @branch
        git_command.concat([@repo.as(String), path])

        # Run the command and check for failures
        run(git_command, fail_error: "unable to clone git repository")

        # Clone was successful
        changed
      end
    end
  end
end
