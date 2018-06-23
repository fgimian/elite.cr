require "unixium"

module Elite::Actions
  Elite.data FindData, paths : Array(String)

  class Find < Action
    ACTION_NAME = "find"

    argument path : String
    file_attribute_arguments

    argument min_depth : Int32, optional: true
    argument max_depth : Int32, optional: true
    argument types : Array(String), optional: true
    argument patterns : Array(String), optional: true
    argument aliases : Bool, default: true

    def process
      # Ensure that home directories are taken into account
      path = File.expand_path(@path.as(String))

      # Check that the path exists
      unless File.directory?(path)
        raise ActionProcessingError.new("Unable to find a directory with the path provided")
      end

      # Find all the paths with the filters provided and return them to the user
      paths = walk(path, path.count(File::SEPARATOR), @mode, @owner, @group, @flags,
                   @min_depth, @max_depth, @types, @patterns, @aliases)

      ok(FindData.new(paths: paths))
    end

    def walk(root_path, root_depth, mode = nil, owner = nil, group = nil, flags = nil, min_depth = nil,
             max_depth = nil, types = nil, patterns = nil, aliases = true)
      # Create a list to store all the files found
      paths = [] of String

      # Walk through the base path provided using scandir (for speed)
      dir = Dir.new(root_path)
      dir.each_child do |relative_path|
        path = File.join(root_path, relative_path)

        # Determine the current depth
        depth = path.count(File::SEPARATOR) - root_depth

        # Impose maximum maximum depths
        next if max_depth && depth > max_depth

        # Recurse through directories
        if File.directory?(path) && !File.symlink?(path)
          subpaths = walk(path, root_depth, mode, owner, group, flags, min_depth, max_depth,
                          types, patterns, aliases)
          paths.concat(subpaths)
        end

        # Impose minimum maximum depth
        next if min_depth && depth < min_depth

        if types
          # Determine the file type
          if File.directory?(path)
            file_type = "directory"
          elsif File.symlink?(path)
            file_type = "symlink"
          # TODO: Implement alias support via Objective-C libraries
          # elsif aliases
          #   # Determine if the file is an alias
          #   url = NSURL.fileURLWithPath_(path)
          #   ok, is_alias, error = url.getResourceValue_forKey_error_(nil, NSURLIsAliasFileKey, nil)
          #   file_type = ok && is_alias ? "alias" : "file"
          else
            file_type = "file"
          end

          # Impose limiting of types
          next unless types.includes?(file_type)
        end

        # Determine the mode, owner, group and flags if requested
        if mode || owner || group || flags
          stat = Unixium::File.stat(path, follow_symlinks: false)

          # Impose searching for a specific file mode
          # We must use a bitwise & 0o777 to remove preceeding bits
          next if mode && stat.st_mode & 0o777 != mode

          if owner
            begin
              uid = Unixium::Users.get(owner).uid
            rescue Unixium::Users::UserNotFoundError
              raise ActionProcessingError.new("The owner requested was not found")
            end

            # Impose limiting searched files by owner
            next if stat.st_uid != uid
          end

          if group
            begin
              gid = Unixium::Groups.get(group).gid
            rescue Unixium::Groups::GroupNotFoundError
              raise ActionProcessingError.new("The group requested was not found")
            end

            # Impose limiting searched files by group
            next if stat.st_gid != gid
          end

          if flags
            flags_bin = 0

            flags.each do |flag|
              unless FLAGS.has_key?(flag)
                raise ActionProcessingError.new("The specified flag is unsupported")
              end
              flags_bin |= FLAGS[flag]
            end

            # Impose filtering files by flag
            next if stat.st_flags & flags_bin == 0
          end
        end

        # Impose filtering by pattern
        next if patterns && !patterns.map { |p| File.match?(p, path) }.any?

        # If we reach this point, then the path passed all filters and should be added
        paths << path
      end
      dir.close

      paths
    end
  end
end
