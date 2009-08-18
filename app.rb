require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'

use Rack::ShowStatus

configure do
  set :sessions, true
  @@config = YAML.load_file("config.yaml") rescue nil || {}
end

before do
  @user = session[:user]
  @client = TwitterOAuth::Client.new(
    :consumer_key => @@config['consumer_key'],
    :consumer_secret => @@config['consumer_secret'],
    :token => session[:access_token],
    :secret => session[:secret_token]
  )
  @rate_limit_status = @client.rate_limit_status
end

get '/' do
  redirect '/timeline' if @user
  @tweets = @client.public_timeline
  erb :home
end

get '/timeline' do
  @tweets = @client.user
  erb :timeline
end

get '/signup' do
  @flash_mess = ''
  erb :signup
end

get '/success' do
  erb :success
end

post '/signup' do
  @mixiclient = MixiClient.new
  redirect '/success' if @mixiclient.login(params[:email], params[:password])

  @flash_mess = 'Mixiのログインに失敗しました。'
  erb :signup
end


post '/update' do
  @client.update(params[:update].toutf8)
  redirect '/timeline'
end

get '/messages' do
  @sent = @client.sent_messages
  @received = @client.messages
  erb :messages
end

get '/search' do
  query = params[:q] || ''
  @search = @client.search(query, params[:page])
  erb :search
end

# store the request tokens and send to Twitter
get '/connect' do
  request_token = @client.request_token(:oauth_callback => @@config['oauth_confirm_url'])
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url
end

# auth URL is called by twitter after the user has accepted the application
# this is configured on the Twitter application settings page
get '/auth' do
  # Exchange the request token for an access token.
  @access_token = @client.authorize(
    session[:request_token],
    session[:request_token_secret],
    :oauth_verifier => params[:oauth_verifier]
  )
  
  if @client.authorized?
      # Storing the access tokens so we don't have to go back to Twitter again
      # in this session.  In a larger app you would probably persist these details somewhere.
      session[:access_token] = @access_token.token
      session[:secret_token] = @access_token.secret
      session[:user] = true
      redirect '/signup'
    else
      redirect '/'
  end
end

get '/disconnect' do
  session[:user] = nil
  session[:request_token] = nil
  session[:request_token_secret] = nil
  session[:access_token] = nil
  session[:secret_token] = nil
  redirect '/'
end

helpers do 
  def partial(name, options={})
    erb("_#{name.to_s}".to_sym, options.merge(:layout => false))
  end
end
