require "http/client"
require "uri"

module Elite::Actions
  Elite.data DownloadData, path : String

  class Download < Action
    ACTION_NAME = "download"

    argument url : String
    argument path : String
    file_attribute_arguments

    def process
      url = @url.as(String)

      # Ensure that home directories are taken into account
      path = File.expand_path(@path.as(String))

      # Download the requested URL to the destination path
      begin
        HTTP::Client.get(url) do |response|
          # Check for a bad HTTP status code
          if response.status_code != 200
            raise ActionProcessingError.new("Unable to retrieve the download URL requested")
          end

          # Determine if the user has provided a full filepath to download to
          filepath = ""

          if File.directory?(path)
            filename : String? = nil

            # Use the download headers to determine the download filename
            if response.headers.has_key?("Content-Disposition")
              content_disposition = response.headers["Content-Disposition"]
              # Workaround: Crystal provides no native way of parsing the Content-Disposition
              # header so I'm using regular expressions instead
              md = content_disposition.match(/attachment; filename="(?<filename>.*)"/)
              filename = md["filename"] if md
            end

            # Use the URL to determine the download filename
            unless filename
              url_path = URI.parse(url).path.as(String)
              # Note that I don't use File.basename here as it results in issues with
              # URLs with trailing slashes which don't contain a filename
              filename = URI.unescape(url_path).split("/").last
            end

            # No filename could be determined
            unless filename && filename != ""
              raise ActionProcessingError.new("Unable to determine the filename of the download")
            end

            # Determine if the user has provided a full filepath to download to
            if File.directory?(path)
              # Build the full filepath using the path given and filename determined
              filepath = File.join([path, filename])

              # Check if the file already exists in the destination path
              if File.exists?(filepath)
                changes_made = set_file_attributes(filepath)
                return changes_made ? changed(DownloadData.new(path: filepath)) : ok
              end
            else
              filepath = path
            end
          else
            filepath = path
          end

          # Download the file
          begin
            File.write(filepath, response.body_io)
          rescue Errno
            raise ActionProcessingError.new("Unable to write the download to the path requested")
          end

          set_file_attributes(filepath)
          changed(DownloadData.new(path: filepath))
        end
      rescue Socket::Error
        raise ActionProcessingError.new("Unable to retrieve the download URL requested")
      end
    end
  end
end
