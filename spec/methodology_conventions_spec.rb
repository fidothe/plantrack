require File.expand_path(File.dirname(__FILE__) + '/spec_helper.rb')
require 'methodology_conventions'

describe MethodologyConventions do
  it "should know what extension story-or-equivalent files should have" do
    MethodologyConventions.story_extension.should == '.story'
  end
  
  it "should know what the name of the directory containing story-or-equivalent files should be" do
    MethodologyConventions.story_dirname.should == 'stories'
  end
  
  it "should know what the file name of the list file should be" do
    MethodologyConventions.list_filename.should == 'story_list'
  end
end