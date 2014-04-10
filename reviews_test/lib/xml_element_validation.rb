require 'nokogiri'
require 'trollop'
require 'open-uri'
require_relative '../common/test_spec'

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


  def save_log
    @log_filename ||= %{#{Time.now.strftime('%Y_%m_%d_%H_%M')}.log}
    File.open("#{@log_folder}/#{@log_filename}", "a") do |f|
      f.puts @log
    end
  end


  def run_element_verification

    @test_start_time = Time.now

    puts "Test started at #{@test_start_time}"
    puts "Progress: "

    @log += <<-EOR
Test started at #{@test_start_time}
    EOR

    if @channel == "all"

      @log += <<-EOR
Selected all channels for test
      EOR

      @specs.each do |product_name, product_spec|

        @log += <<-EOR
Starting test for channel '#{product_name}'
        EOR

        test_spec = TestSpec.new(product_spec).test_spec
        test_document = xml_body(product_name)

      end
    else

      @log += <<-EOR
Selected '#{@channel.chomp}' channel for test
      EOR

      test_spec = TestSpec.new(@specs[@channel.chomp]).test_spec
      test_document = xml_body(@channel.chomp)
    end

    @log += <<-EOR
XML is loaded
    EOR

    report_writer(run_test(test_document, test_spec))

    @test_end_time = Time.now
    @test_duration = @test_end_time - @test_start_time

    @log += <<-EOR

Test finished at #{@test_end_time}
Test duration: #{@test_duration} sec
    EOR

    save_log
    puts "\nTest completed at #{@test_end_time}"
    puts "Test duration: #{@test_duration} sec"
  end


  def xml_body(channel)
    begin
      if @input_file.nil?
        if @limit == '0'
          uri = "http://api.#{@domain}/api/v2/reviews/browse?api_key=#{@api_key}&channel=#{channel.chomp}"
        else
          uri = "http://api.#{@domain}/api/v2/reviews/browse?api_key=#{@api_key}&channel=#{channel.chomp}&limit=#{@limit}"
        end

        @log += <<-EOR
URL for xml file is: #{uri}
        EOR

        xml_body = Nokogiri::XML(open(uri))
      else

        @log += <<-EOR
Filename of xml file is: #{@input_file}
        EOR

        xml_body = Nokogiri::XML(File.open(@input_file))
      end
    rescue Exception => e

      @log += <<-EOR
URL or filename is incorrect: #{e.message}
      EOR
    end
    xml_body
  end


  def test_status_analyzer(test_result)
    result = OpenStruct.new

    test_statuses = []

    unless test_result.test_of_value.nil?
      test_statuses << test_result.test_of_value.test_status
    end

    unless test_result.test_of_attributes.nil?
      test_statuses << test_result.test_of_attributes.test_status
    end

    unless test_result.test_of_child_elements.nil?
      test_statuses << test_result.test_of_child_elements.test_status
    end

    if test_statuses.include?("FAIL")
      result.test_status = "FAIL"
    else
      result.test_status = "PASS"
    end

    @log += <<-EOR

Test of element summary result: #{result.test_status}
    EOR

    result
  end


  def attribute_verification(test_element, expected_attributes)

    begin

      test_attributes = []

      expected_attributes.each do |expected_attribute|

        @log += <<-EOR

Test of attribute, Attribute id: #{expected_attribute["attribute_id"]}
Test of attribute, Attribute name: #{expected_attribute["attribute_name"]}
        EOR

        test_attribute = OpenStruct.new
        test_attribute.id = expected_attribute["attribute_id"]
        test_attribute.name = expected_attribute["attribute_name"]
        test_attribute.expected_value = expected_attribute["attribute_value"]
        test_attribute.actual_value = test_element.attribute(expected_attribute["attribute_name"].gsub(":","|")).to_s

        if expected_attribute["attribute_value"] == "*"

          if test_attribute.actual_value == ""
            test_attribute.test_status = "FAIL"
            test_attribute.test_message = %{For attribute '#{expected_attribute["attribute_name"]}' value is empty!}
          else
            test_attribute.test_status = "PASS"
          end

        elsif expected_attribute["attribute_value"].include? ','

          expected_attribute_values = expected_attribute["attribute_value"].gsub(/\s/,'').split(',')

          if expected_attribute_values.include? test_attribute.actual_value.to_s
            test_attribute.test_status = "PASS"
          else
            test_attribute.test_status = "FAIL"
            test_attribute.test_message = %{For attribute '#{expected_attribute["attribute_name"]}' value is incorrect!}
          end

        else

          if test_attribute.actual_value == expected_attribute["attribute_value"]
            test_attribute.test_status = "PASS"
          else
            test_attribute.test_status = "FAIL"
            test_attribute.test_message = %{For attribute '#{expected_attribute["attribute_name"]}' value is incorrect!}
          end
        end

        @log += <<-EOR
Test of attribute, Actual result: #{test_attribute.actual_value}
Test of attribute, Expected result: #{test_attribute.expected_value}
Test of attribute, Test result: #{test_attribute.test_status}
        EOR

        unless test_attribute.test_message.nil?
          @log += <<-EOR
Test of attribute, Test message: #{test_attribute.test_message}
          EOR
        end

        test_attributes << test_attribute
      end

      test_results = OpenStruct.new
      test_results.attributes = test_attributes

      attributes_statuses = test_attributes.map { |attribute| attribute.test_status }
      attributes_messages = test_attributes.select { |attribute| attribute.test_message }.map { |attribute| attribute.test_message }


      if attributes_statuses.include? "FAIL"
        test_results.test_status = "FAIL"
        test_results.test_message = attributes_messages.compact.join(", ")
      else
        test_results.test_status = "PASS"
      end

    rescue Exception => e

      @log += <<-EOR
Unexpected error in attribute validation method, error: #{e.message}
      EOR

      save_log
    end

    test_results
  end


  def value_validation(test_element, expected_value)

    @log += <<-EOR

Value validation, Actual value: #{test_element.text}
Value validation, Expected value: #{expected_value}
    EOR

    begin
      test_of_value = OpenStruct.new

      if expected_value == "*"
        if test_element.text == ""
          test_of_value.test_status = "FAIL"
          test_of_value.test_message = "Element value is empty!"
        else
          test_of_value.test_status = "PASS"
        end
      else
        if test_element.text == expected_value
          test_of_value.test_status = "PASS"
        else
          test_of_value.test_status = "FAIL"
          test_of_value.test_message = "Element value is incorrect!"
        end
      end

      @log += <<-EOR
Value validation, Test result: #{test_of_value.test_status}
      EOR

      unless test_of_value.test_message.nil?
        @log += <<-EOR
Value validation, Test message: #{test_of_value.test_message}
        EOR
      end

    rescue Exception => e

      @log += <<-EOR
Unexpected error in value validation method, error: #{e.message}
      EOR

      save_log
    end

    test_of_value
  end


  def child_elements_validation(test_element, expected_child_elements)

    @log += <<-EOR

Child element validation:
#{"*"*120}
    EOR

    test_results = OpenStruct.new
    test_results.child_elements = test_of_elements(test_element, expected_child_elements)


    if test_results.child_elements.any? { |child_element| child_element.test_status == "FAIL" }
      test_results.test_status = "FAIL"
    else
      test_results.test_status = "PASS"
    end


    @log += <<-EOR

Child element validation, Test result: #{test_results.test_status}
#{"*"*120}
    EOR

    test_results
  end


  def test_of_elements(test_node, test_elements)

    elements = []

    test_elements.each do |element|

      text_message = " Test element id: #{element["element_id"]}, Test element name: #{element["element_name"]} "
      boarder = "-"*((120 - text_message.size)/2)

      @log += <<-EOR

#{ boarder + text_message + boarder }
      EOR

      element_test_result = OpenStruct.new
      element_test_result.id = element["element_id"]
      element_test_result.name = element["element_name"]

      test_element =  test_node.css(element["element_name"].gsub(":","|"))

      # Verifying element existence
      if test_element.to_s == ""
        element_test_result.test_status = "FAIL"
        element_test_result.test_message = "Element not exist!"

        @log += <<-EOR
Test of element existence, Element not exist

Test of element summary result: #{ element_test_result.test_status }
        EOR

        elements << element_test_result
        next
      end


      # Verifying element value
      element_test_result.test_of_value = value_validation(test_element, element['element_value']) unless element['element_value'].nil?

      # Verifying element attributes
      element_test_result.test_of_attributes = attribute_verification(test_element, element['attributes']) unless element['attributes'].nil?

      # Verifying child elements
      element_test_result.test_of_child_elements = child_elements_validation(test_element, element['child_elements']) unless element['child_elements'].nil?


      analyzed_results = test_status_analyzer(element_test_result)
      element_test_result.test_status = analyzed_results.test_status
      element_test_result.test_message = analyzed_results.test_message


      elements << element_test_result
    end

    elements
  end


  def run_test(test_document, test_spec)

    all_nodes = test_document.css(test_spec["container"].gsub(":","|"))

    if  all_nodes.empty?

      @log += <<-EOR
Unable to locate container element '#{test_spec["container"]}'
      EOR

      raise "Unable to locate container element"
    end

    all_nodes.map do |container|
      test_node = OpenStruct.new
      test_node.id = (/\d+/.match container.search('id').text).to_s

      print "#"

      @log += <<-EOR
#{"="*120}
Test element id is #{test_node.id}
#{"="*120}
      EOR

      test_node.elements = test_of_elements(container, test_spec['elements'])
      test_node
    end
  end


  def report_writer(test_report)
    filename = %{#{Time.now.strftime('%Y_%m_%d_%H_%M')}_#{@channel}_channel.txt}
    File.open("#{@output_folder}/#{filename}", "w") do |f|
      test_report.each do |node|
        f.puts("="*120)
        f.puts "Tested element ID: #{node.id}"
        f.puts("="*120)
        node['elements'].each do |element|
          f.puts("Element ##{element.id}: <#{element.name}>") if element.test_status == "FAIL"

          if !element.test_of_value.nil? && element.test_of_value.test_status == "FAIL"
            f.puts("")
            f.puts("Element value validation")
            f.puts("#{element.test_of_value.test_status} - #{element.test_of_value.test_message}")
            f.puts("-"*120)
          end

          if !element.test_of_attributes.nil? && element.test_of_attributes.test_status == "FAIL"
            f.puts("")
            f.puts("Attribute validation:")
            failed_attribues = element.test_of_attributes.attributes.select { |attr| attr.test_status ==  "FAIL" }
            failed_attribues.each do |attribute|
              f.puts("#{attribute.test_status} - Attribute ##{attribute.id}: #{attribute.name}")
              f.puts("Expected value: #{attribute.expected_value}")
              f.puts("Actual value: #{attribute.actual_value}")
              f.puts("Test message: #{attribute.test_message}")
              f.puts("-"*120)
            end
          end


          if !element.test_of_child_elements.nil? && element.test_of_child_elements.test_status == "FAIL"
            f.puts("")
            f.puts("Child elements validation:")
            element.test_of_child_elements.child_elements.each do |child_element|

              f.puts("Child element ##{child_element.id}: <#{child_element.name}>") if child_element.test_status == "FAIL"

              if !child_element.test_of_value.nil? && child_element.test_of_value.test_status == "FAIL"
                f.puts("")
                f.puts("Chield element value validation")
                f.puts("#{child_element.test_of_value.test_status} - #{child_element.test_of_value.test_message}")
                f.puts("-"*120)
              end


              if !child_element.test_of_attributes.nil? && child_element.test_of_attributes.test_status == "FAIL"
                f.puts("")
                f.puts("Child element attribute validation:")
                failed_attribues = child_element.test_of_attributes.attributes.select { |attr| attr.test_status ==  "FAIL" }
                failed_attribues.each do |attribute|
                  f.puts("#{attribute.test_status} - Child attribute ##{attribute.id}: #{attribute.name}")
                  f.puts("Expected value: #{attribute.expected_value}")
                  f.puts("Actual value: #{attribute.actual_value}")
                  f.puts("Test message: #{attribute.test_message}")
                  f.puts("-"*120)
                end
              end
            end
          end
        end
        f.puts("")
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
#    opt :input_file, "Relative path to the input xml file, instead of using remote server", :short => "-i", :type => :string, :default => ""
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
  #Trollop::die :input_file, "Input xml file (#{opts[:input_file]}) not found" unless (File.exists?(opts[:input_file]))
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
