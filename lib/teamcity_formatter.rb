
class TeamCityFormatter < XCPretty::Simple

  def format_error(message)
    "##teamcity[testStdErr name='className.testName' out='#{message}']"
  end

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
  
  # Return empty strings for all warning methods. Modi is too bad, and our build 
  # logs are actually too big that TC can't return them without crashing the browser.
  def format_warning(message)
    "" # return nothing
  end

  def format_compile_warning(file_name, file_path, reason, line, cursor)
    "" # return nothing
  end

  def format_ld_warning(message)
    "" # return nothing
  end

end

TeamCityFormatter
