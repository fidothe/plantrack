require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

module Plantrack
  describe Project do
    it "should be able to be instantiated" do
      Project.new('dir', :conventions).should be_instance_of(Project)
    end
    
    describe "instances" do
      before(:each) do
        @project = Project.new('/path/to/dir', :conventions)
      end
      
      it "should be able to figure out what its list dirs are" do
        Dir.expects(:glob).with('/path/to/dir/*').returns(['/path/to/dir_1', '/path/to/dir/2', '/path/to/file'])
        File.expects(:directory?).with('/path/to/dir_1').returns(true)
        File.expects(:directory?).with('/path/to/dir/2').returns(true)
        File.expects(:directory?).with('/path/to/file').returns(false)
        
        @project.list_dir_paths.should == ['/path/to/dir_1', '/path/to/dir/2']
      end
      
      it "should be able to create List objects for each of its list dirs" do
        @project.stubs(:list_dir_paths).returns(['/path', '/other/path'])
        
        List.expects(:new).with('/path', :conventions).returns(:list_1)
        List.expects(:new).with('/other/path', :conventions).returns(:list_2)
        
        @project.lists.should == [:list_1, :list_2]
      end
      
      it "should be able to serialize everything" do
        mock_list = mock('List')
        @project.stubs(:lists).returns([mock_list])
        
        mock_list.expects(:serialise_all!)
        
        @project.serialise!
      end
    end
  end
end
