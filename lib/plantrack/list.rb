module Plantrack
  class List
    class << self
      def parse_file(file_path)
        prioritised_stories = []
        unprioritised_stories = []
        current_stories = prioritised_stories
        new_entry = /^\[/
        prioritised_separator = /^---+$/
        found_prioritised_separator = nil
        File.open(file_path, 'r') do |f|
          while line = f.gets
            line = line.strip
            case line
            when new_entry
              current_story = [line]
              current_stories << current_story
            when prioritised_separator
              found_prioritised_separator = line
              current_stories = unprioritised_stories
            else
              current_story << line
            end
          end
        end
        
        result = {}
        result[:prioritised] = prioritised_stories.collect {|story| parse_entry(story)}
        result[:unprioritised] = unprioritised_stories.collect {|story| parse_entry(story)}
        result[:prioritised_separator] = found_prioritised_separator if found_prioritised_separator
        result
      end
      
      def entry_parsing_regexp
        @entry_parser ||= /^\[([\w_-]+)\] *: *(.+)$/m
      end
      
      def parse_entry(entry)
        entry_text = entry.collect { |line| line == '' ? "\n" : line + ' ' }.join('').strip
        match_data = entry_text.match(entry_parsing_regexp)
        match_data ? match_data.captures : []
      end
    end
    
    attr_reader :dir, :path
    
    def initialize(dir, conventions)
      @conventions = conventions
      @dir = dir
      @path = File.join(dir, @conventions.list_filename)
      @parsed_list = self.class.parse_file(@path)
    end
    
    def prioritised_stories
      @prioritised_stories ||= prioritised_story_data.collect { |story_data| make_story(*story_data) }
    end
    
    def unprioritised_stories
      @unprioritised_stories ||= (unprioritised_story_data + unaccounted_for_story_data).collect { |story_data| make_story(*story_data) }
    end
    
    def serialise!
      File.open(path, 'w') { |f| f.write(serialised_text) }
    end
    
    def serialise_all!
      serialise!
      (prioritised_stories + unprioritised_stories).each { |story| story.serialise! }
    end
    
    private
    
    def parsed_prioritised
      @parsed_list[:prioritised]
    end
    
    def parsed_unprioritised
      @parsed_list[:unprioritised]
    end
    
    def story_dir
      "#{dir}/#{@conventions.story_dirname}"
    end
    
    def filesystem_story_paths
      story_paths = Hash.new('')
      Dir.glob("#{story_dir}/**/*#{@conventions.story_extension}").collect do |path|
        story_paths[File.basename(path, @conventions.story_extension)] = path
      end
      story_paths
    end
    
    def correlate_story_data(story_data)
      story_data.collect { |name, title| [filesystem_story_paths[name], name, title]}
    end
    
    def prioritised_story_data
      correlate_story_data(parsed_prioritised)
    end
    
    def unprioritised_story_data
      correlate_story_data(parsed_unprioritised)
    end
    
    def unaccounted_for_story_data
      accounted_for_names = (parsed_prioritised + parsed_unprioritised).collect { |name, title| name }
      filesystem_story_paths.reject { |name, path| accounted_for_names.include?(name) }.collect { |name, path| [path, name, nil] }
    end
    
    def make_story(path, name, title)
      path = "#{story_dir}/#{name}#{@conventions.story_extension}" if path == ''
      Story.new(path, name, title)
    end
    
    def serialised_story(story, output_lines, max_story_name_length, line_padding)
      line_wrap_position = 75
      first_line_padding = max_story_name_length - story.name.length
      unwrapped_story_text = "#{' ' * first_line_padding}[#{story.name}]: #{story.title}"
      break_position = unwrapped_story_text.rindex(/\s/, line_wrap_position)
      while (unwrapped_story_text.length > line_wrap_position) && break_position && (break_position < unwrapped_story_text.length)
        output_lines << unwrapped_story_text[0..break_position]
        unwrapped_story_text = (' ' * line_padding) + (unwrapped_story_text[break_position..-1].strip)
        break_position = unwrapped_story_text.rindex(/\s/, line_wrap_position)
      end
      output_lines << unwrapped_story_text
    end
    
    def serialised_text
      max_story_name_length = (prioritised_stories + unprioritised_stories).max { |a, b| a.name.length <=> b.name.length }.name.length
      line_padding = max_story_name_length + 4 # 2 for the square brackets, 1 for the colon, and 1 for the space
      story_lines = []
      prioritised_stories.each do |story|
        serialised_story(story, story_lines, max_story_name_length, line_padding)
      end
      story_lines << ''
      unless unprioritised_stories.empty?
        story_lines << (' ' * line_padding) + '----'
        story_lines << ''
        unprioritised_stories.each do |story| 
          serialised_story(story, story_lines, max_story_name_length, line_padding)
        end
        story_lines << ''
      end
      story_lines.join($/)
    end
  end
end