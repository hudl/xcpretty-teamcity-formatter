require 'fileutils'
require 'json'

# This is a hybrid of a teamcity and json formatter for xcpretty.
# It is also modified to not print warnings to the standard out,
# because modi has too many warning it becomes ridiculous.
# Eventually as warnings decrease we might be able to remove that aspect though.
# https://github.com/XappMedia/xcpretty-teamcity-formatter
# https://github.com/marcelofabri/xcpretty-json-formatter/
class TeamCityFormatter < XCPretty::Simple
  FILE_PATH = 'build/reports/errors.json'.freeze

  def initialize(use_unicode, colorize)
    super
    STDOUT.puts "##teamcity[compilationStarted compiler='xcodebuild']"
    @warnings = []
    @ld_warnings = []
    @compile_warnings = []
    @errors = []
    @compile_errors = []
    @file_missing_errors = []
    @undefined_symbols_errors = []
    @duplicate_symbols_errors = []
    @failures = {}
    @tests_summary_messages = []
    at_exit do
      STDOUT.puts "##teamcity[compilationFinished compiler='xcodebuild']"
    end
  end

  # These first 6 overrides don't log to the json file.
  def format_failing_test(suite, test, time, file_path)
    "##teamcity[testStarted name='#{test}']\n" +
        "##teamcity[testFailed name='#{test}' message='#{time}']\n" +
        "##teamcity[testFinished name='#{test}']"
  end

  def format_check_dependencies()
    "##teamcity[progressMessage 'Check dependencies']"
  end

  def format_build_target(target, project, configuration)
    "##teamcity[progressMessage 'Building #{target}']"
  end

  def format_compile(file_name, file_path)
    "##teamcity[progressMessage 'Compiling #{file_name}']"
  end

  def format_touch(file_path, file_name)
    "##teamcity[progressMessage 'Touching #{file_name}']"
  end

  def format_phase_success(phase_name)
    "##teamcity[progressMessage '#{phase_name} Success']"
  end

  # The rest of the overrides log to the json file.

  # Return empty strings for all warning methods. Modi is too bad, and our build 
  # logs are actually too big that TC can't return them without crashing the browser.
  def format_ld_warning(message)
    @ld_warnings << message
    write_to_file_if_needed
    "" # return nothing
  end

  def format_warning(message)
    @warnings << message
    write_to_file_if_needed
    "" # return nothing
  end

  def format_compile_warning(file_name, file_path, reason, line, cursor)
    @compile_warnings << {
      file_name: file_name,
      file_path: file_path,
      reason: reason,
      line: line,
      cursor: cursor
    }
    write_to_file_if_needed
    "" # return nothing
  end

  def format_error(message)
    @errors << message
    write_to_file_if_needed
    "##teamcity[testStdErr name='className.testName' out='#{message}']"
  end

  def format_compile_error(file, file_path, reason, line, cursor)
    @compile_errors << {
      file_name: file,
      file_path: file_path,
      reason: reason,
      line: line,
      cursor: cursor
    }
    write_to_file_if_needed
    teamcity_error_message("CompileError", "#{file_path}: #{reason}\n#{line}\n#{cursor}")
    super
  end

  def format_file_missing_error(reason, file_path)
    @file_missing_errors << {
      file_path: file_path,
      reason: reason
    }
    write_to_file_if_needed
    teamcity_error_message("FileMissingError", "#{file_path}: #{reason}")
    super
  end

  def format_undefined_symbols(message, symbol, reference)
    @undefined_symbols_errors = {
      message: message,
      symbol: symbol,
      reference: reference
    }
    write_to_file_if_needed
    teamcity_error_message("UndefinedSymbolsError",
      "#{message}\n" \
      "> Symbol: #{symbol}\n" \
      "> Referenced from: #{reference}")
    super
  end

  def format_duplicate_symbols(message, file_paths)
    @duplicate_symbols_errors = {
      message: message,
      file_paths: file_paths
    }
    write_to_file_if_needed
    teamcity_error_message("DuplicateSymbolsError",
      "#{message}\n" \
      "> #{file_paths.join("\n> ")}")
    super
  end

  def format_test_summary(message, failures_per_suite)
    @failures.merge!(failures_per_suite)
    @tests_summary_messages << message
    write_to_file_if_needed
    super
  end

  def teamcity_error_message(message, details)
    STDOUT.puts "##teamcity[message text='#{message}' errorDetails='#{format_details(details)}' status='ERROR']\n"
  end

  def format_details(detail)
    detail.gsub('|', '||')
          .gsub("\n", '|n')
          .gsub("'", "|'")
          .gsub('[', '|[')
          .gsub(']', '|]')
  end

  def finish
    write_to_file
    super
  end

  def json_output
    {
      warnings: @warnings,
      ld_warnings: @ld_warnings,
      compile_warnings: @compile_warnings,
      errors: @errors,
      compile_errors: @compile_errors,
      file_missing_errors: @file_missing_errors,
      undefined_symbols_errors: @undefined_symbols_errors,
      duplicate_symbols_errors: @duplicate_symbols_errors,
      tests_failures: @failures,
      tests_summary_messages: @tests_summary_messages
    }
  end

  def write_to_file_if_needed
    write_to_file unless XCPretty::Formatter.method_defined? :finish
  end

  def write_to_file
    file_name = ENV['XCPRETTY_JSON_FILE_OUTPUT'] || FILE_PATH
    dirname = File.dirname(file_name)
    FileUtils.mkdir_p dirname

    File.open(file_name, 'w') do |io|
      io.write(JSON.pretty_generate(json_output))
    end
  end
end

TeamCityFormatter
