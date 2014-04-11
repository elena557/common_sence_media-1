require 'nokogiri'
require 'trollop'
require 'open-uri'
require_relative '../common/test_spec'
require_relative '../common/custom_error'


$MODULE_DIR = File.expand_path(File.dirname(__FILE__)).gsub(/lib/, '')

class XmlValidator

  def initialize(domain, api_key, channel, limit, specs, input_file, output_folder, log_folder)
    @log = ''
    @domain = domain
    @api_key = api_key
    @channel = channel
    @limit = limit
    @specs = specs
    @input_file = input_file
    @output_folder = output_folder
    @log_folder = log_folder
  end


  def save_log_message(message)
    @log_filename ||= %{#{@test_start_time.strftime('%Y_%m_%d_%H_%M')}_#{@channel}.log}
    File.open("#{@log_folder}/#{@log_filename}", "a") do |f|
      f.puts message
    end
  end


  def run_test_with_report(product_name, product_spec)
    @test_start_time = Time.now
    start_report

    puts "Test started at #{@test_start_time}"
    save_log_message "Test started at #{@test_start_time}"
    puts "\nStarting test for channel '#{product_name}'"
    save_log_message "Starting test for channel '#{product_name}'"

    puts "Loading XML..."

    test_spec = TestSpec.new(product_spec).test_spec
    test_document = xml_body(product_name)


    puts "XML is loaded."
    save_log_message "XML is loaded"
    puts "\nProgress: "

    run_test(test_document, test_spec)

    finish_report
    puts "\nTest completed at #{@test_end_time}"
    save_log_message "Test finished at #{@test_end_time}"
    puts "Test duration: #{@test_duration}"
    save_log_message "Test duration: #{@test_duration} sec"
  end


  def run_element_verification
    if @channel == "all"
      @specs.each do |product_name, product_spec|
        run_test_with_report(product_name, product_spec)
      end
    else
      run_test_with_report(@channel.chomp, @specs[@channel.chomp])
    end
  end


  def xml_body(channel)
    begin

      if @limit == '0'
        uri = "http://api.#{@domain}/api/v2/reviews/browse?api_key=#{@api_key}&channel=#{channel.chomp}"
      else
        uri = "http://api.#{@domain}/api/v2/reviews/browse?api_key=#{@api_key}&channel=#{channel.chomp}&limit=#{@limit}"
      end


      save_log_message "URL for xml file is: #{uri}"

      xml_body = Nokogiri::XML(open(uri))

    rescue Exception => e
      save_log_message "URL is incorrect: #{e.message}"
      raise "URL or filename is incorrect: #{e.message}"
    end

    xml_body
  end


  def test_status_analyzer(test_result)
    begin

      result = {}
      test_statuses = []

      unless test_result[:test_of_value].nil?
        test_statuses << test_result[:test_of_value][:test_status]
      end

      unless test_result[:test_of_attributes].nil?
        test_statuses << test_result[:test_of_attributes][:test_status]
      end

      unless test_result[:test_of_child_elements].nil?
        test_statuses << test_result[:test_of_child_elements][:test_status]
      end

      if test_statuses.include?("FAIL")
        result[:test_status] = "FAIL"
      elsif test_statuses.include?("BLOCK")
        result[:test_status] = "BLOCK"
      else
        result[:test_status] = "PASS"
      end

      save_log_message "Test of element summary result: #{result[:test_status]}"

    rescue Exception => e

      save_log_message "Unexpected error in test_status_analyzer method, error: #{e.message}"
      raise XmlValidatorMethodError, "Unexpected error in test_status_analyzer method, error: #{e.message}" unless e.include?('method, error:')
    end

    result
  end


  def attribute_verification(test_element, expected_attributes)

    begin

      test_attributes = []

      expected_attributes.each do |expected_attribute|
        begin

          save_log_message ""
          save_log_message "Test of attribute, Attribute id: #{expected_attribute["attribute_id"]}"
          save_log_message "Test of attribute, Attribute name: #{expected_attribute["attribute_name"]}"

          test_attribute = {}

          test_attribute[:id] = expected_attribute["attribute_id"]
          test_attribute[:name] = expected_attribute["attribute_name"]
          test_attribute[:expected_value] = expected_attribute["attribute_value"]
          test_attribute[:actual_value] = test_element.attribute(expected_attribute["attribute_name"].gsub(":","|")).to_s

          if expected_attribute["attribute_value"] == "*"

            if test_attribute[:actual_value] == ""
              test_attribute[:test_status] = "FAIL"
              test_attribute[:test_message] = %{For attribute '#{expected_attribute["attribute_name"]}' value is empty!}
            else
              test_attribute[:test_status] = "PASS"
            end

          elsif expected_attribute["attribute_value"].include? ','

            expected_attribute_values = expected_attribute["attribute_value"].gsub(/\s/,'').split(',')

            if expected_attribute_values.include? test_attribute[:actual_value].to_s
              test_attribute[:test_status] = "PASS"
            else
              test_attribute[:test_status] = "FAIL"
              test_attribute[:test_message] = %{For attribute '#{expected_attribute["attribute_name"]}' value is incorrect!}
            end

          else

            if test_attribute[:actual_value] == expected_attribute["attribute_value"]
              test_attribute[:test_status] = "PASS"
            else
              test_attribute[:test_status] = "FAIL"
              test_attribute[:test_message] = %{For attribute '#{expected_attribute["attribute_name"]}' value is incorrect!}
            end
          end

          save_log_message "Test of attribute, Actual result: #{test_attribute[:actual_value]}"
          save_log_message "Test of attribute, Expected result: #{test_attribute[:expected_value]}"
          save_log_message "Test of attribute, Test result: #{test_attribute[:test_status]}"

          unless test_attribute[:test_message].nil?
            save_log_message "Test of attribute, Test message: #{test_attribute[:test_message]}"
          end

        rescue Exception => e
          test_attribute[:test_status] = "BLOCK"
          test_attribute[:test_message] = "Unexpected error in attribute_verification method, error: #{e.message}"
          test_attributes << test_attribute
          next
        end
        test_attributes << test_attribute
      end

      test_results = {}
      test_results[:attributes] = test_attributes

      attributes_statuses = test_attributes.map { |attribute| attribute[:test_status] }
      attributes_messages = test_attributes.select { |attribute| attribute[:test_message] }.map { |attribute| attribute[:test_message] }


      if attributes_statuses.include? "FAIL"
        test_results[:test_status] = "FAIL"
        test_results[:test_message] = attributes_messages.compact.join(", ")
      elsif attributes_statuses.include? "BLOCK"
        test_results[:test_status] = "BLOCK"
        test_results[:test_message] = attributes_messages.select { |attribute| attribute[:test_message].include?('error')}
      else
        test_results[:test_status] = "PASS"
      end

    rescue Exception => e

      save_log_message "Unexpected error in attribute_verification method, error: #{e.message}"
      test_results[:test_status] = "BLOCK"
      test_results[:test_message] = "Unexpected error in attribute_verification method, error: #{e.message}"
      test_results
    end

    test_results
  end


  def value_validation(test_element, expected_value)
    begin

      save_log_message ""
      save_log_message "Value validation, Actual value: #{test_element.text}"
      save_log_message "Value validation, Expected value: #{expected_value}"

      test_of_value = {}

      if expected_value == "*"
        if test_element.text == ""
          test_of_value[:test_status] = "FAIL"
          test_of_value[:test_message] = "Element value is empty!"
        else
          test_of_value[:test_status] = "PASS"
        end
      else
        if test_element.text == expected_value
          test_of_value[:test_status] = "PASS"
        else
          test_of_value[:test_status] = "FAIL"
          test_of_value[:test_message] = "Element value is incorrect!"
        end
      end

      save_log_message "Value validation, Test result: #{test_of_value[:test_status]}"


      unless test_of_value[:test_message].nil?
        save_log_message "Value validation, Test message: #{test_of_value[:test_message]}"
      end

    rescue Exception => e

      save_log_message "Unexpected error in value_validation method, error: #{e.message}"
      test_of_value[:test_status] = "BLOCK"
      test_of_value[:test_message] = "Unexpected error in value_validation method, error: #{e.message}"
      test_of_value
    end

    test_of_value
  end


  def child_elements_validation(test_element, expected_child_elements)
    begin

      save_log_message ""
      save_log_message "Child element validation:"
      save_log_message "#{"*"*120}"

      test_results = {}

      test_results[:child_elements] = test_of_elements(test_element, expected_child_elements)

      if test_results[:child_elements].any? { |child_element| child_element[:test_status] == "FAIL" }
        test_results[:test_status] = "FAIL"
      elsif test_results[:child_elements].any? { |child_element| child_element[:test_status] == "BLOCK" }
        test_results[:test_status] = "BLOCK"
      else
        test_results[:test_status] = "PASS"
      end


      save_log_message ""
      save_log_message "Child element validation, Test result: #{test_results[:test_status]}"
      save_log_message "#{"*"*120}"

    rescue Exception => e

      save_log_message "Unexpected error in child_elements_validation method, error: #{e.message}"
      test_results[:test_status] = "BLOCK"
      test_results[:test_message] = "Unexpected error in child_elements_validation method, error: #{e.message}"
      test_results
    end

    test_results
  end


  def test_of_elements(test_node, test_elements)
    begin

      elements = []

      test_elements.each do |element|

        text_message = " Test element id: #{element["element_id"]}, Test element name: #{element["element_name"]} "
        boarder = "-"*((120 - text_message.size)/2)

        save_log_message "#{ boarder + text_message + boarder }"

        element_test_result = {}
        element_test_result[:id] = element["element_id"]
        element_test_result[:name] = element["element_name"]

        test_element =  test_node.css(element["element_name"].gsub(":","|"))

        # Verifying element existence
        if test_element.to_s == ""
          element_test_result[:test_status] = "FAIL"
          element_test_result[:test_message] = "Element not exist!"

          save_log_message "Test of element existence, Element not exist"
          save_log_message ""
          save_log_message "Test of element summary result: #{ element_test_result[:test_status] }"

          elements << element_test_result
          next
        end

        # Verifying element value
        element_test_result[:test_of_value] = value_validation(test_element, element['element_value']) unless element['element_value'].nil?

        # Verifying element attributes
        element_test_result[:test_of_attributes] = attribute_verification(test_element, element['attributes']) unless element['attributes'].nil?

        # Verifying child elements
        element_test_result[:test_of_child_elements] = child_elements_validation(test_element, element['child_elements']) unless element['child_elements'].nil?


        analyzed_results = test_status_analyzer(element_test_result)
        element_test_result[:test_status] = analyzed_results[:test_status]
        element_test_result[:test_message] = analyzed_results[:test_message]

        elements << element_test_result
      end

    rescue Exception => e
      save_log_message "Unexpected error in test_of_elements method, error: #{e.message}"
    end
    elements
  end


  def run_test(test_document, test_spec)
    begin

      all_nodes = test_document.css(test_spec["container"].gsub(":","|"))
      if  all_nodes.empty?

        save_log_message "Unable to locate container element '#{test_spec["container"]}'"
        raise "Unable to locate container element"
      end

      number_of_results = 0
      all_nodes.each do |container|
        test_node = {}

        test_node[:id] = (/\d+/.match container.search('id').text).to_s


        save_log_message "#{"="*120}"
        save_log_message "Test element id is #{test_node[:id]}"
        save_log_message "#{"="*120}"

        test_node[:elements] = test_of_elements(container, test_spec['elements'])

        report_writer([test_node])

        number_of_results += 1
        print "\rTested #{number_of_results} nodes..."
      end

      @number_elements = number_of_results

      save_log_message ""
      save_log_message "Number of nodes tested: #{@number_elements}"

      puts "\nNumber of nodes tested: #{@number_elements}"

    rescue Exception => e
      save_log_message "Unexpected error in run_test method, error: #{e.message}"
    end
  end


  def start_report
    write_report do |file|
      file.puts "Test start time: #{@test_start_time}"
    end
  end


  def finish_report
    write_report do |file|
      @test_end_time = Time.now
      time_difference = @test_end_time - @test_start_time
      minutes = time_difference.to_i/60
      second = time_difference.to_i - minutes * 60
      @test_duration = "#{minutes} min #{second} sec"

      file.puts "Test end time: #{@test_end_time}"
      file.puts "Test duration: #{@test_duration}"
      file.puts "Number of tested elements: #{@number_elements}"
    end
  end


  def write_report
    @filename ||= %{#{@test_start_time.strftime('%Y_%m_%d_%H_%M')}_#{@channel}.txt}

    File.open("#{@output_folder}/#{@filename}", "a") do |file|
      yield file
    end
  end


  def report_writer(test_report)

    write_report do |f|

      test_report.each do |node|

        f.puts("="*120)
        f.puts "Tested element ID: #{node[:id]}"
        f.puts("="*120)

        node[:elements].each do |element|

          if element[:test_status] == "FAIL" || element[:test_status] == "BLOCK"
            f.puts("")
            text_message = " Test element id: #{element[:id]}, Test element name: #{element[:name]} "
            boarder = "-"*((120 - text_message.size)/2)
            f.puts boarder + text_message + boarder
          end

          if !element[:test_of_value].nil? && (element[:test_of_value][:test_status] == "FAIL" || element[:test_of_value][:test_status] == "BLOCK")
            f.puts("")
            f.puts("Test of element value, Test status: #{element[:test_of_value][:test_status]}")
            f.puts("Test of element value, Test message: #{element[:test_of_value][:test_message]}")
          end

          if !element[:test_of_attributes].nil? && (element[:test_of_attributes][:test_status] == "FAIL" || element[:test_of_attributes][:test_status] == "BLOCK")
            failed_attribues = element[:test_of_attributes][:attributes].select { |attr| attr[:test_status] ==  "FAIL" }
            failed_attribues.each do |attribute|
              f.puts("")
              f.puts("Test of attribute, Attribute id ##{attribute[:id]}")
              f.puts("Test of attribute, Attribute name: #{attribute[:name]}")
              f.puts("Test of attribute, Expected value: #{attribute[:expected_value]}")
              f.puts("Test of attribute, Actual value: #{attribute[:actual_value]}")
              f.puts("Test of attribute, Test status: #{attribute[:test_status]}")
              f.puts("Test of attribute, Test message: #{attribute[:test_message]}")
            end
          end


          if !element[:test_of_child_elements].nil? && (element[:test_of_child_elements][:test_status] == "FAIL" || element[:test_of_child_elements][:test_status] == "BLOCK")
            f.puts("")
            f.puts("Child elements validation:")
            f.puts("*"*120)
            element[:test_of_child_elements][:child_elements].each do |child_element|

              if child_element[:test_status] == "FAIL"
                text_message = " Child element id: #{child_element[:id]}, name: <#{child_element[:name]}> "
                boarder = "-"*((120 - text_message.size)/2)
                f.puts boarder + text_message + boarder
              end


              if !child_element[:test_of_value].nil? && (child_element[:test_of_value][:test_status] == "FAIL" || child_element[:test_of_value][:test_status] == "BLOCK")
                f.puts("")
                f.puts("Child element test of value, Test status: #{child_element[:test_of_value][:test_status]}")
                f.puts("Child element test of value, Test message: #{child_element[:test_of_value][:test_message]}")
              end


              if !child_element[:test_of_attributes].nil? && (child_element[:test_of_attributes][:test_status] == "FAIL" || child_element[:test_of_attributes][:test_status] == "BLOCK")
                f.puts("")
                failed_attribues = child_element[:test_of_attributes][:attributes].select { |attr| attr[:test_status] ==  "FAIL" || attr[:test_status] ==  "BLOCK" }
                failed_attribues.each do |attribute|
                  f.puts("Child element test of attribute, Child attribute id: #{attribute[:id]}")
                  f.puts("Child element test of attribute, Child attribute name: #{attribute[:name]}")
                  f.puts("Child element test of attribute, Child attribute expected value: #{attribute[:expected_value]}")
                  f.puts("Child element test of attribute, Child attribute actual value: #{attribute[:actual_value]}")
                  f.puts("Child element test of attribute, Test status: #{attribute[:test_status]}")
                  f.puts("Child element test of attribute, Test message: #{attribute[:test_message]}")
                end
              end

              unless child_element[:test_message].nil?
                f.puts(child_element[:test_message])
              end
            end
            f.puts("*"*120)
          end

          unless element[:test_message].nil?
            f.puts(element[:test_message])
          end
        end
        f.puts("")
        f.puts("")
      end
    end
  end
end



if (__FILE__ == $0)

  banner_title = File.basename($0, ".*").gsub("_", " ").split(" ").each { |word| word.capitalize! }.join(" ") + " Test"
  default_movie_element_spec = File.join($MODULE_DIR,'etc','movie_element.json')
  default_game_element_spec = File.join($MODULE_DIR,'etc','game_element.json')
  default_app_element_spec = File.join($MODULE_DIR,'etc','app_element.json')
  default_website_element_spec = File.join($MODULE_DIR,'etc','website_element.json')
  default_tv_element_spec = File.join($MODULE_DIR,'etc','tv_element.json')
  default_book_element_spec = File.join($MODULE_DIR,'etc','book_element.json')
  default_music_element_spec = File.join($MODULE_DIR,'etc','music_element.json')
  default_report_directory = File.join($MODULE_DIR,'reports')
  default_log_directory = File.join($MODULE_DIR,'log')

  Dir.mkdir(default_report_directory) unless File.exists?(default_report_directory)
  Dir.mkdir(default_log_directory) unless File.exists?(default_log_directory)

  opts = Trollop::options do
    banner <<-EOB
  #{banner_title}

    #{$0} [options]

  Where options are:

    EOB

    opt :domain, "Domain name of the website", :short => "-d", :type => :string, :default => "commonsensemedia.org"
    opt :api_key, "API key for access", :short => "-k", :type => :string, :default => "4bc231a2f0486a481425379be3093307"
    opt :channel, "Channel for test: all, movie, game, app, website, tv, show, book, music", :short => "-c", :type => :string, :default => "all"
    opt :limit, "Number of product for test: all or any number", :short => "-l", :type => :string, :default => '0'
    opt :log_file_folder, "Relative to the log file", :type => :string, :default => default_log_directory

    opt :movie_element_spec, "Relative path to the movie element specification file", :type => :string, :default => default_movie_element_spec
    opt :game_element_spec, "Relative path to the game element specification file", :type => :string, :default => default_game_element_spec
    opt :app_element_spec, "Relative path to the show element specification file", :type => :string, :default => default_app_element_spec
    opt :website_element_spec, "Relative path to the website element specification file ", :type => :string, :default => default_website_element_spec
    opt :tv_element_spec, "Relative path to the tv element specification file", :type => :string, :default => default_tv_element_spec
    opt :book_element_spec, "Relative path to the book element specification file", :type => :string, :default => default_book_element_spec
    opt :music_element_spec, "Relative path to the music element specification file ", :type => :string, :default => default_music_element_spec

    opt :output_report_directory, "The output directory where output report file will be located", :short => "-o", :type => :string, :default => default_report_directory
  end


  # options validation
  Trollop::die :domain, "Domain name is missing" unless (opts[:domain])
  Trollop::die :movie_element_spec, "test specification file (#{opts[:movie_element_spec]}) not found" unless (File.exists?(opts[:movie_element_spec]))
  Trollop::die :game_element_spec, "test specification file (#{opts[:game_element_spec]}) not found" unless (File.exists?(opts[:game_element_spec]))
  Trollop::die :app_element_spec, "test specification file (#{opts[:app_element_spec]}) not found" unless (File.exists?(opts[:app_element_spec]))
  Trollop::die :website_element_spec, "test specification file (#{opts[:website_element_spec]}) not found" unless (File.exists?(opts[:website_element_spec]))
  Trollop::die :tv_element_spec, "test specification file (#{opts[:tv_element_spec]}) not found" unless (File.exists?(opts[:tv_element_spec]))
  Trollop::die :book_element_spec, "test specification file (#{opts[:book_element_spec]}) not found" unless (File.exists?(opts[:book_element_spec]))
  Trollop::die :music_element_spec, "test specification file (#{opts[:music_element_spec]}) not found" unless (File.exists?(opts[:music_element_spec]))


  specs = {
    'movie'   => opts[:movie_element_spec],
    'game'    => opts[:game_element_spec],
    'app'    => opts[:app_element_spec],
    'website' => opts[:website_element_spec],
    'tv'      => opts[:tv_element_spec],
    'book'    => opts[:book_element_spec],
    'music'   => opts[:music_element_spec]
          }

  xml_test = XmlValidator.new(opts[:domain],opts[:api_key], opts[:channel], opts[:limit], specs, opts[:input_file], opts[:output_report_directory], opts[:log_file_folder])
  xml_test.run_element_verification
end
