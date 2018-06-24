require "file_utils"

module Elite::Actions
  Elite.data FileData, path : String

  class File < Action
    ACTION_NAME = "file"

    argument path : String
    argument source : String, optional: true
    argument state : String, choices: ["file", "directory", "alias", "symlink", "absent"],
             default: "file"
    file_attribute_arguments

    def validate_arguments
      if @source && @state == "directory"
        raise ActionProcessingError.new(
          "The file action doesn't support copyng one directory to another, use the " \
          "rsync action instead"
        )
      end

      if @source && @state == "absent"
        raise ActionProcessingError.new(%(The "source" argument may not be provided when "state" is "absent"))
      end

      if !@source && @state == "symlink"
        raise ActionProcessingError.new(%(The "source" argument must be provided when "state" is "symlink"))
      end
    end

    def process
      # Ensure that home directories are taken into account
      path = ::File.expand_path(@path.as(String))
      source = ::File.expand_path(@source.as(String)) if @source

      case @state
      when "file"
        if source
          # The source provided does not exist or is not a file
          unless ::File.file?(source)
            raise ActionProcessingError.new("The source provided could not be found or is not a file")
          end

          # If the destination provided is a path, then we place the file in it
          if ::File.directory?(path)
            path = ::File.join(path, ::File.basename(source))
          end

          # An existing file at the destination path was found so we compare them
          # and avoid making changes if they"re identical
          exists = ::File.file?(path)
          if exists && md5(source) == md5(path)
            changes_made = set_file_attributes(path)
            data = FileData.new(path: path)
            return changes_made ? changed(data) : ok(data)
          end

          # Copy the source to the destination
          copy(source, path)

          set_file_attributes(path)
          changed(FileData.new(path: path))
        else
          # An existing file at the destination path was found
          if ::File.file?(path)
            changes_made = set_file_attributes(path)
            data = FileData.new(path: path)
            return changes_made ? changed(data) : ok(data)
          end

          # Create an empty file at the destination path
          create_empty(path)

          set_file_attributes(path)
          changed(FileData.new(path: path))
        end
      when "directory"
        # An existing directory was found
        if ::File.directory?(path)
          changes_made = set_file_attributes(path)
          data = FileData.new(path: path)
          return changes_made ? changed(data) : ok(data)
        end

        # Clean any existing item in the path requested
        remove(path)

        # Create the directory requested
        begin
          Dir.mkdir(path)
        rescue Errno
          raise ActionProcessingError.new("The requested directory could not be created")
        end

        set_file_attributes(path)
        changed(FileData.new(path: path))
      # # TODO: Implement alias support via Objective-C libraries
      # when "alias"
      #   # If the destination provided is a path, then we place the file in it
      #   if ::File.directory?(path)
      #     path = ::File.join(path, ::File.basename(source))
      #   end

      #   # When creating an alias, the source must be an absolute path and exist
      #   source = ::File.expand_path(source)
      #   unless ::File.exists?(source)
      #     raise ActionProcessingError.new("The source file provided does not exist")
      #   end

      #   # An existing alias at the destination path was found so we compare them
      #   # and avoid making changes if they"re identical
      #   exists = ::File.file?(path)
      #   path_url = NSURL.fileURLWithPath_(path)

      #   if exists
      #     bookmark_data, error = NSURL.bookmarkDataWithContentsOfURL_error_(
      #       path_url, None
      #     )

      #     if bookmark_data
      #       source_url, is_stale, error = NSURL.URLByResolvingBookmarkData_options_relativeToURL_bookmarkDataIsStale_error_(  # flake8: noqa
      #         bookmark_data, NSURLBookmarkResolutionWithoutUI, None, None, None
      #       )
      #       if source_url.path == source
      #         changes_made = set_file_attributes(path)
      #         data = FileData.new(path: path)
      #         changes_made ? changed(data) : ok(data)
      #       end
      #     end
      #   end

      #   # Delete any existing file or symlink at the path
      #   remove(path)

      #   # Create an NSURL object for the source (absolute paths must be used for aliases)
      #   source_url = NSURL.fileURLWithPath_(source)

      #   # Build the bookmark for the alias
      #   bookmark_data, error = source_url.bookmarkDataWithOptions_includingResourceValuesForKeys_relativeToURL_error_(
      #     NSURLBookmarkCreationSuitableForBookmarkFile, None, None, None
      #   )

      #   # Write the alias using the bookmark data
      #   if bookmark_data
      #     success, error = NSURL.writeBookmarkData_toURL_options_error_(
      #       bookmark_data, path_url, NSURLBookmarkCreationSuitableForBookmarkFile, None
      #     )
      #   else
      #     raise ActionProcessingError.new("Unable to create alias")
      #   end

      #   set_file_attributes(path)
      #   changed(FileData.new(path: path))
      when "symlink"
        # We are certain that source is set for symlinks due to validation method
        source = source.as(String)

        # If the destination provided is a path, then we place the file in it
        if ::File.directory?(path) && !::File.symlink?(path)
          path = ::File.join(path, ::File.basename(source))
        end

        # An existing symlink at the destination path was found so we compare them
        # and avoid making changes if they"re identical
        exists = ::File.symlink?(path)
        if exists && ::File.real_path(path) == source
          changes_made = set_file_attributes(path)
          data = FileData.new(path: path)
          return changes_made ? changed(data) : ok(data)
        end

        # Delete any existing file or symlink at the path
        remove(path)

        # Create the symlink requested
        begin
          ::File.symlink(source, path)
        rescue Errno
          raise ActionProcessingError.new("The requested symlink could not be created")
        end

        set_file_attributes(path)
        changed(FileData.new(path: path))
      else # "absent"
        removed = remove(path)
        data = FileData.new(path: path)
        removed ? changed(data) : ok(data)
      end
    end

    private def copy(source, path)
      FileUtils.cp(source, path)
    rescue Errno
      raise ActionProcessingError.new("Unable to copy source file to path requested")
    end

    private def create_empty(path)
      ::File.open(path, "w") {}
    rescue ex : Errno
      if ex.errno == Errno::EISDIR
        raise ActionProcessingError.new("The destination path is a directory")
      else
        raise ActionProcessingError.new("Unable to create an empty file at the path requested")
      end
    end

    private def remove(path)
      return false unless ::File.exists?(path) || ::File.symlink?(path)

      if ::File.file?(path)
        begin
          FileUtils.rm(path)
        rescue Errno
          raise ActionProcessingError.new("Existing file could not be removed")
        end
      elsif ::File.directory?(path)
        begin
          FileUtils.rm_r(path)
        rescue Errno
          raise ActionProcessingError.new("Existing directory could not be recursively removed")
        end
      elsif ::File.symlink?(path)
        begin
          FileUtils.rm(path)
        rescue Errno
          raise ActionProcessingError.new("Existing symlink could not be removed")
        end
      end

      true
    end

    # Using the OpenSSL version installed by Homebrew is much faster than the Digest library
    private def md5(path)
      slice = Bytes.new(65_536)
      digest = OpenSSL::Digest.new("MD5")
      ::File.open(path, "rb") do |file|
        io = OpenSSL::DigestIO.new(file, digest)
        loop do
          read = io.read(slice)
          break if read == 0
        end
        io.hexdigest
      end
    rescue Errno
      raise Errno.new("Unable to determine checksum of file")
    end
  end
end
