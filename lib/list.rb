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
    Story.new(path, title)
  end
  
  def serialised_text
    max_story_name_length = (prioritised_stories + unprioritised_stories).max { |a, b| a.name.length <=> b.name.length }.name.length
    story_lines = prioritised_stories.collect do |story|
      first_line_padding = max_story_name_length - story.name.length
      (' ' * first_line_padding) + "[#{story.name}]: #{story.title}"
    end
    story_lines << ''
    unless unprioritised_stories.empty?
      story_lines << (' ' * max_story_name_length) + ' ----'
      story_lines << ''
      story_lines = story_lines + unprioritised_stories.collect do |story| 
        first_line_padding = max_story_name_length - story.name.length
        (' ' * first_line_padding) + "[#{story.name}]: #{story.title}"
      end
      story_lines << ''
    end
    story_lines.join($/)
  end
end