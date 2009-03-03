module Plantrack
  class Project
    attr_reader :dir, :conventions
    
    def initialize(dir, conventions)
      @dir = dir
      @conventions = conventions
    end
    
    def list_dir_paths
      candidates = Dir.glob(File.expand_path(dir + '/*'))
      candidates.select { |path| File.directory?(path) }
    end
    
    def lists
      @lists ||= list_dir_paths.collect { |path| List.new(path, conventions) }
    end
    
    def serialise!
      lists.each { |list| list.serialise_all! }
    end
  end
end
