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
  
  @@uc_flg = false
end

before do
  # loginflgの設定
  @login_flg = session[:login_flg]

  # 工事中FLGですべての画面UCにリダイレクト
  redirect 'uc' if request.path_info != '/uc' && request.path_info != '/css/main.css' && @@uc_flg
  @debug_flg = false

  # Twitterクライント接続不要箇所など非接続
  if request.path_info =~ /[.ico|.jpg|.css|^\/uc|^\/]$/
    @client = nil
  else
    @client = TwitterOAuth::Client.new(
     :consumer_key => @@config['consumer_key'],
      :consumer_secret => @@config['consumer_secret'],
      :token => session[:access_token],
      :secret => session[:secret_token]
    )
  end
end

get '/' do
  redirect '/signup' if @login_flg
  erb :home
end

get '/signup' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg

  # もし直リンクだったら/に戻す
#  redirect '/' if session[:access_token] == nil || session[:secret_token] == nil

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
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg

  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == '' || session[:secret_token] == ''

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
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg

  erb :success
end

# 退会
get '/unregist' do
  # 未ログインだったら/に戻す
  if @login_flg
    erb :unregist
  else
    redirect '/'
  end
end

# 退会(実行)
post '/unregist' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg

  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == '' || session[:secret_token] == ''

  if @@user_dao.unregist
    @login_flg = nil
    session[:login_flg] = nil
    session[:access_token] = nil
    session[:secret_token] = nil
    @flash_mess = 'Twitter2mixi登録を解除しました。'
    erb :unregist_success
  else
    @flash_mess = 'Twitter2mixi登録解除に失敗しました。'
    erb :unregist
  end
end

# OAuth承認
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
  # 引数が無ければ/に戻す
  redirect '/' unless params[:oauth_verifier]

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
    session[:login_flg] = true
    redirect '/signup'
  else
    redirect '/'
  end
end

# ログアウト
get '/disconnect' do
  # セッションの初期化
  session[:login_flg] = nil
  session[:request_token] = nil
  session[:request_token_secret] = nil
  session[:access_token] = nil
  session[:secret_token] = nil

  redirect '/'
end


# 工事中画面
get '/uc' do
  # 工事中FLGでなければHOMEへリダイレクト
  redirect '/' if not @@uc_flg

  erb :uc
end

helpers do 
  def partial(name, options={})
    erb("_#{name.to_s}".to_sym, options.merge(:layout => false))
  end
end
