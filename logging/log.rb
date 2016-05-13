require 'utils/console.rb'

class Log
  attr_reader :log

  # At the moment only OS X can handle lo4r, because Windows has a mismatch with thread.so
  if (true || Rescape::Config.darwin?)
    require 'stringio'
    require 'log4r'
    require 'log4r/outputter/datefileoutputter'
    include Log4r
  end

  def initialize(path, filename)
    if (true || Rescape::Config.darwin?)
      string_iooutputter = Class.new(IOOutputter) do
        attr_reader :log
        def initialize(name, hash)
          @buffer = ""
          io = StringIO.new(@buffer, "w+")
          super('user', io, hash)
        end
        def write(data)
          puts data
        end
      end
      @log = Logger.new(filename)
      format = PatternFormatter.new(:pattern => "[ %d ] %l\t %m")
      @log.add(string_iooutputter.new('console', {:formatter=>format}))
      file_log = DateFileOutputter.new('fileOutputter', :dirname=>path, :trunc => false, :date_pattern=>"#{filename}_%Y-%m-%d", :formatter=> format )
      @log.level = Rescape::Config::LOG_LEVEL
      @log.add file_log
      puts "Logging to #{file_log.filename}"
      @log.info "Starting log"
    else
      # Windows doesn't support log4r because of problems with thread.so
      @log = FakeLogger.new(path, filename)
    end
  end
end


class FakeLogger
  def initialize(path, filename)
    @filename = Time.now.strftime("#{path}/#{filename}_%Y-%m-%d.log")
  end

  def info(message)
    if Rescape::Config::LOG_LEVEL <= 2
      formatted_message = "#{Time.now.to_s}: #{message}"
      File.open(@filename, 'a') {|f| f.puts(formatted_message)}
      formatted_message
    end
  end

  def warn(message)
    if Rescape::Config::LOG_LEVEL <= 3
      formatted_message = "#{Time.now.to_s}: #{message}"
      File.open(@filename, 'a') {|f| f.puts(formatted_message)}
      formatted_message
    end
  end

  def error(message)
    if Rescape::Config::LOG_LEVEL <= 4
      formatted_message = "#{Time.now.to_s}: #{message}"
      File.open(@filename, 'a') {|f| f.puts(formatted_message)}
      formatted_message
    end
  end
end