class Story
  class << self
    META_SEP = %r/\A---\s*(?:\r\n|\n)?\z/   # :nodoc: # totally stolen from Webby, http://webby.rubyforge.org/
    
    def parse_file_components(file_path)
      raise ArgumentError, "File '#{file_path}' doesn't exist!" unless File.file?(file_path)
      f = File.open(file_path)
      yaml_buffer = []
      text_buffer = []
      separator_not_passed = true
      
      current_buffer = yaml_buffer
      
      while line = f.gets
        if line =~ META_SEP && separator_not_passed
          separator_not_passed = false
          current_buffer = text_buffer
        else
          current_buffer << line
        end
      end
      
      [YAML.load(yaml_buffer.join('')), text_buffer.join('')]
    end
  end
  
  attr_reader :yaml, :text, :path, :name
  
  def initialize(file_path, name, title)
    @path = file_path
    @name = name
    @yaml, @text = File.exists?(file_path) ? self.class.parse_file_components(file_path) : [{}, '']
    @yaml['title'] = title unless title.nil? || title.empty?
  end
  
  def title
    @yaml['title']
  end
  
  def serialise!
    File.open(path, 'w') { |f| f.write(serialised_text) }
  end
  
  private
  
  def serialised_text
    yaml_block = @yaml.to_yaml.split("\n")
    yaml_block.shift
    yaml_block.join("\n") + "#{$/}---#{$/}" + text
  end
end