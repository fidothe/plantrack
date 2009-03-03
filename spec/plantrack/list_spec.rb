require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

module Plantrack
  describe List do
    def mock_conventions
      @mock_conventions ||= stub('stub MethodologyConventions', :story_extension => '.story', 
                                                                :story_dirname => 'stories', 
                                                                :list_filename => 'list')
    end
    
    it "should be able to parse a file for its text" do
      fixture_io = StringIO.new(read_fixture('simple_list_fixture.txt'))
      File.expects(:open).with('file_path', 'r').yields(fixture_io)
      
      List.parse_file('file_path').should == {:prioritised   => [['BacklogItem', 'Title here'], 
                                                                 ['OtherBacklogItem', 'Another title']],
                                              :unprioritised => [['who_knows', 'A title']],
                                              :prioritised_separator => '------'}
    end
    
    it "should be able to create a new instance given a dir, filename, and story dirname" do
      # maybe some config instance thing instead of story dirname, to figure out extensions
      List.expects(:parse_file).with('dir/list').returns(:results)
      
      list = List.new('dir', mock_conventions)
      list.dir.should == 'dir'
      list.path.should == 'dir/list'
    end
    
    describe "parsing entries" do
      it "should be able to parse a one-line entry" do
        List.publicize_methods do
          List.parse_entry("[StoryName]: Description").should == ['StoryName', 'Description']
        end
      end
      
      it "should be able to parse a multi-line one-paragraph entry" do
        List.publicize_methods do
          List.parse_entry(["[StoryName]: Description", "Some other description text"]).
            should == ['StoryName', "Description Some other description text"]
        end
      end
      
      it "should be able to parse a multi-line multi-paragraph entry" do
        List.publicize_methods do
          List.parse_entry(["[StoryName]: Description", "Some other description text", "", "Other para"]).
            should == ['StoryName', "Description Some other description text \nOther para"]
        end
      end
    end
    
    describe "instances" do
      before(:each) do
        List.stubs(:parse_file)
        @list = List.new('dir', mock_conventions)
      end
      
      it "should be able to create a list of stories from looking at the file system" do
        Dir.expects(:glob).with('dir/stories/**/*.story').returns(['grouping/what_a_good.story', 'BacklogItem.story'])
        List.publicize_methods do
          @list.filesystem_story_paths.should == {'what_a_good' => 'grouping/what_a_good.story',
                                                  'BacklogItem' => 'BacklogItem.story'}
        end
      end
      
      it "should be able to make a new story object given path, name and title" do
        Story.expects(:new).with('grouping/what_a_good.story', 'what_a_good', 'Item title').returns(:story)
        
        List.publicize_methods do
          @list.make_story('grouping/what_a_good.story', 'what_a_good', 'Item title').should == :story
        end
      end
      
      it "should be able to make a new story object given name and title" do
        Story.expects(:new).with('dir/stories/what_a_good.story', 'what_a_good', 'Item title').returns(:story)
        
        List.publicize_methods do
          @list.make_story('', 'what_a_good', 'Item title').should == :story
        end
      end
      
      it "should be able to construct a list of all of a given kind of stories tied to filesystem paths" do
        @list.stubs(:filesystem_story_paths).returns({'what_a_good' => 'grouping/what_a_good.story',
                                                      'BacklogItem' => 'BacklogItem.story',
                                                      'Other_item' => 'Other_item.story'})
        List.publicize_methods do
          @list.correlate_story_data([['Other_item', 'Another title'], ['BacklogItem', 'Title']]).
            should == [['Other_item.story', 'Other_item', 'Another title'], 
                       ['BacklogItem.story', 'BacklogItem', 'Title']]
        end
      end
      
      it "should be able to expose a list of prioritised story data" do
        @list.stubs(:parsed_prioritised).returns([['Other_item', 'Another title'], ['BacklogItem', 'Title']])
        @list.expects(:correlate_story_data).with([['Other_item', 'Another title'], ['BacklogItem', 'Title']]).
          returns(:data)
        List.publicize_methods do
          @list.prioritised_story_data.should == :data
        end
      end
      
      it "should be able to expose a list of unprioritised story data" do
        @list.stubs(:parsed_unprioritised).returns([['what_a_good', 'Great title']])
        @list.expects(:correlate_story_data).with([['what_a_good', 'Great title']]).
          returns(:data)
        List.publicize_methods do
          @list.unprioritised_story_data.should == :data
        end
      end
      
      it "should be able to report unaccounted-for unprioritised stories (i.e. files on disk)" do
        @list.stubs(:parsed_unprioritised).returns([['what_a_good', 'Great title']])
        @list.stubs(:parsed_prioritised).returns([['Other_item', 'Another title'], ['BacklogItem', 'Title']])
        @list.stubs(:filesystem_story_paths).returns({'what_a_good' => 'grouping/what_a_good.story',
                                                      'BacklogItem' => 'BacklogItem.story',
                                                      'AnotherBacklogItem' => 'AnotherBacklogItem.story',
                                                      'Other_item' => 'Other_item.story'})
        
        List.publicize_methods do
          @list.unaccounted_for_story_data.should == [['AnotherBacklogItem.story', 'AnotherBacklogItem', nil]]
        end
      end
      
      it "should expose a list of prioritised story objects" do
        @list.expects(:make_story).with('BacklogItem.story', 'BacklogItem', 'Title').returns(:story)
        @list.stubs(:prioritised_story_data).returns([['BacklogItem.story', 'BacklogItem', 'Title']])
        @list.prioritised_stories.should == [:story]
      end
      
      it "should expose a list of unprioritised story objects" do
        @list.expects(:make_story).with('BacklogItem.story', 'BacklogItem', 'Title').returns(:story_one)
        @list.expects(:make_story).with('AnotherBacklogItem.story', 'AnotherBacklogItem', nil).returns(:story_two)
        @list.stubs(:unprioritised_story_data).returns([['BacklogItem.story', 'BacklogItem', 'Title']])
        @list.stubs(:unaccounted_for_story_data).returns([['AnotherBacklogItem.story', 'AnotherBacklogItem', nil]])
        @list.unprioritised_stories.should == [:story_one, :story_two]
      end
      
      describe "serialising themselves" do
        describe "generating the text" do
          it "should correctly generate the text when there are no unprioritised items" do
            mock_story = stub('Story', :name => 'BacklogItem', :title => 'My Backlog item')
            @list.stubs(:prioritised_stories).returns([mock_story])
            @list.stubs(:unprioritised_stories).returns([])
            
            List.publicize_methods do
              @list.serialised_text.should == "[BacklogItem]: My Backlog item\n"
            end
          end
          
          it "should correctly generate the text when there are no unprioritised items but multiple prioritised items" do
            mock_story_one = stub('Story', :name => 'BacklogItem', :title => 'My backlog item')
            mock_story_two = stub('Story', :name => 'SecondBacklogItem', :title => 'My other backlog item')
            @list.stubs(:prioritised_stories).returns([mock_story_one, mock_story_two])
            @list.stubs(:unprioritised_stories).returns([])
            
            List.publicize_methods do
              @list.serialised_text.should == "      [BacklogItem]: My backlog item\n[SecondBacklogItem]: My other backlog item\n"
            end
          end
          
          it "should correctly generate the text when there are unprioritised items" do
            mock_story_one = stub('Story', :name => 'BacklogItem', :title => 'My backlog item')
            mock_story_two = stub('Story', :name => 'UnprioritisedBacklogItem', :title => 'My other backlog item')
            @list.stubs(:prioritised_stories).returns([mock_story_one])
            @list.stubs(:unprioritised_stories).returns([mock_story_two])
            
            List.publicize_methods do
              @list.serialised_text.
                should == "             [BacklogItem]: My backlog item\n\n                            ----\n\n[UnprioritisedBacklogItem]: My other backlog item\n"
            end
          end
          
          it "should correctly wrap the text for items when serialising" do
            mock_story = stub('Story', :name => 'BacklogItem', :title => 'My Backlog item has lots of words which mean that it will need to be broken before it hits the magic 75 column mark but only just, well maybe twice')
            @list.stubs(:prioritised_stories).returns([mock_story])
            @list.stubs(:unprioritised_stories).returns([])
            
            expected = "[BacklogItem]: My Backlog item has lots of words which mean that it will \n               need to be broken before it hits the magic 75 column mark \n               but only just, well maybe twice\n"
            
            List.publicize_methods do
              @list.serialised_text.should == expected
            end
          end
        end
        
        it "should be able to serialise itself to disk" do
          mock_file = mock('list File')
          File.expects(:open).with('dir/list', 'w').yields(mock_file)
          mock_file.expects(:write).with(:serialised_text)
          @list.stubs(:serialised_text).returns(:serialised_text)
          
          @list.serialise!
        end
        
        it "should be able to serialise itself and its stories to disk" do
          mock_story = stub('Story')
          @list.stubs(:prioritised_stories).returns([mock_story])
          @list.stubs(:unprioritised_stories).returns([])
          
          mock_story.expects(:serialise!)
          @list.expects(:serialise!)
          
          @list.serialise_all!
        end
      end
    end
  end
end