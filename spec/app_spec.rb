require 'lib/app'
require 'spec/spec_helper'

describe 'GET /' do
  before :all do
    get '/'
  end

  it "statusコードは200であるべき" do
    last_response.ok?.should be_true
  end

  it "responseは'<html>\\n<head>\\n' kara hajimaru" do
    last_response.body.should =~ /<html>\n<hrad>/
  end

  it "@tweetsをもつべき" do
    last_app.assigns(:tweets).should be_true
  end

  it "viewはhome.erbをつかうこと" do
    last_response.body.should == last_app.erb(:home)
  end

  it "pending"

end
