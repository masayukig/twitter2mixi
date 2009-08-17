require 'rack/test'
require 'singleton'

module MyTestMethods
  def app
    Sinatra::Application
  end
end

Spec::Runner.configure do |config|
  config.include Rack::Test::Methods
  config.include MyTestMethods
end

class SinatraSpecHelper
  include Singleton
  attr_accessor :last_app
end

module Sinatra
  class Base
    def call(env)
      _dup = dup
      SinatraSpecHelper.instance.last_app = _dup
      _dup.call!(env)
    end

    def assigns(sym)
      instance_variables.include?("@#{sym}")
    end
  end
end

module MyTestMethods
  def app
    Sinatra::Application
  end

  def last_app
    SinatraSpecHelper.instance.last_app
  end
end
