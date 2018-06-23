module Elite::Actions
  Elite.data FileInfoData, exists : Bool, file_type : String?, source : String?, mount : Bool?,
                           flags : Array(String)?

  class FileInfo < Action
    ACTION_NAME = "file_info"

    argument path : String
    argument aliases : Bool, default: true

    def process
      # Ensure that home directories are taken into account
      path = File.expand_path(@path.as(String))

      # Check if the filepath exists
      if File.exists?(path)
        exists = true

        # Determine the type of file found
        if File.symlink?(path)
          file_type = "symlink"
          source = File.real_path(path)
        elsif File.directory?(path)
          file_type = "directory"
        # TODO: Implement alias support via Objective-C libraries
        # elsif aliases
        #   # Determine if the file is an alias
        #   alias_url = NSURL.fileURLWithPath_(path)
        #   bookmark_data, error = NSURL.bookmarkDataWithContentsOfURL_error_(alias_url, nil)

        #   if bookmark_data
        #     file_type = "alias"
        #     source_url, is_stale, error = NSURL.URLByResolvingBookmarkData_options_relativeToURL_bookmarkDataIsStale_error_(
        #       bookmark_data, NSURLBookmarkResolutionWithoutUI, nil, nil, nil
        #     )
        #     source = source_url.path()
        #   else
        #     file_type = "file"
        #     source = nil
        #   end
        else
          file_type = "file"
        end

        # Determine if the path is a mountpoint
        mount = Unixium::File.mount?(path)

        # Determine what flags are set on the file
        stat = Unixium::File.stat(path)
        flags = FLAGS.map { |flag, flag_bin| flag unless stat.st_flags & flag_bin == 0 }.compact
      else
        exists = false
      end

      ok(FileInfoData.new(exists: exists, file_type: file_type, source: source, mount: mount,
                          flags: flags))
    end
  end
end
