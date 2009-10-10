require 'test/spec_helper'
require 'app'

describe 'GET /' do
  before :all do
    get '/'
  end

  it "statusコードは200であるべき" do
    last_response.ok?.should be_true
  end

  it "responseは'html' wo motteiru" do
    last_response.body.should =~ /html/
  end

  it "@tweetsをもつべき" do
    last_app.assigns(:tweets).should be_true
  end

  it "viewはhome.erbをつかうこと" do
    last_response.body.should == last_app.erb(:home)
  end

end
