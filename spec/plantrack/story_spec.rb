require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

module Plantrack
  describe Story do
    it "should be able to parse text and yaml out of the top of a file" do
      yaml, text = Story.parse_file_components(fixture_path('yaml_and_text_fixture.txt'))
      
      yaml.should == YAML.load_file(fixture_path('yaml_only_fixture.txt'))
      text.should == File.read(fixture_path('text_only_fixture.txt'))
    end
    
    it "should be able to create a new instance of itself given a file path" do
      yaml_hash = {}
      File.expects(:exists?).with('file_path').returns(true)
      Story.expects(:parse_file_components).with('file_path').returns([yaml_hash, :text])
      
      story = Story.new('file_path', 'name', 'title')
      
      story.yaml.should == yaml_hash
    end
    
    it "should be able to cope when the file given doesn't exist" do
      File.expects(:exists?).with('file_path').returns(false)
      Story.expects(:parse_file_components).with('file_path').never
      
      story = Story.new('file_path', 'name', 'title')
    end
    
    describe "instances" do
      before(:each) do
        File.stubs(:exists?).with('file_path').returns(true)
        Story.stubs(:parse_file_components).with('file_path').returns([{}, 'What a great feature'])
        @story = Story.new('file_path', 'name', 'Story title')
      end
      
      describe "titles" do
        it "should expose their title" do
          @story.title.should == 'Story title'
        end
        
        it "should return the YAML title if none is passed in" do
          Story.stubs(:parse_file_components).with('file_path').returns([{'title' => 'Hello'}, 'What a great feature'])
          story = Story.new('file_path', 'name', '')
          
          story.title.should == 'Hello'
        end
      end
      
      it "should expose their name" do
        @story.name.should == 'name'
      end
      
      it "should expose their path" do
        @story.path.should == 'file_path'
      end
      
      it "should expose their text" do
        @story.text.should == 'What a great feature'
      end
      
      describe "serialising themselves" do
        it "should properly serialise their title to YAML" do
          Story.publicize_methods do
            @story.serialised_text.should == read_fixture('bare_story_after_serialisation.txt')
          end
        end
        
        it "should be able to serialise itself to disk" do
          mock_file = mock('story File')
          File.expects(:open).with('file_path', 'w').yields(mock_file)
          mock_file.expects(:write).with(:serialised_text)
          @story.stubs(:serialised_text).returns(:serialised_text)
          
          @story.serialise!
        end
      end
    end
  end
end