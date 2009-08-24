require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'lib/user_dao'

configure do
  set :sessions, true
  @@config = YAML.load_file("config.yml") rescue nil || {}
  @@user_dao = UserDao.new @@config
  @@mixiclient = MixiClient.new
end

before do
  @user = session[:user]
  if request.path_info != '/'
    @client = TwitterOAuth::Client.new(
     :consumer_key => @@config['consumer_key'],
      :consumer_secret => @@config['consumer_secret'],
      :token => session[:access_token],
      :secret => session[:secret_token]
    )
    @rate_limit_status = @client.rate_limit_status
  else
    @client = nil
    @rate_limit_status = nil
  end
end

get '/' do
  redirect '/signup' if @user
  erb :home
end

get '/signup' do
  @flash_mess = ''
  if @@user_dao.login session[:access_token], session[:secret_token]
    @flash_mess = ''
  else
    @flash_mess = 'Twitter2mixiへ、ようこそ。'
    @@user_dao.twitter_regist session[:access_token], session[:secret_token]
  end
  erb :signup
end

post '/signup' do
  if @@mixiclient.login(params[:email], params[:password])
    @flash_mess = '正しいMixiのアカウント情報を確認できました。'
    @@user_dao.mixi_regist params[:email], params[:password]
    redirect '/success'
  else
    @flash_mess = 'Mixiのログインに失敗しました。'
    erb :signup
  end
end

get '/success' do
  erb :success
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
