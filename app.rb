require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'kconv'
require 'lib/mixi_client'
require 'lib/user_dao'

configure do
  set :sessions, true
  @@config = YAML.load_file("config.yml") rescue nil || {}
  @@uc_flg = false
end

before do
  # loginflgの設定
  @login_flg = session[:login_flg]
  @configenv = @@config['env']
  @configenv_ja = 'ステージング' if @configenv=='staging'
  @configenv_ja = '開発' if @configenv=='development'

  # 工事中FLGですべての画面UCにリダイレクト
  redirect 'uc' if request.path_info != '/uc' && request.path_info != '/css/main.css' && @@uc_flg
  @debug_flg = true

  # user_dao初期化
  if request.path_info != '/'
    @user_dao = UserDao.new @@config
    @user_dao.login session[:access_token], session[:secret_token]
  end

  if request.path_info =~ /[.ico|.jpg|.css|^\/uc|^\/]$/
    @client = nil
  else
    # Twitterクライント初期化
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
  if @user_dao.login session[:access_token], session[:secret_token]
    @flash_mess = ''
  else
    @flash_mess = 'Twitter2mixiへ、ようこそ。'
    @user_dao.twitter_regist session[:access_token], session[:secret_token]
  end
  erb :signup
end

post '/signup' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg

  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == '' || session[:secret_token] == ''
  redirect '/signup' if params[:email] == '' || params[:password] == ''

  mixiclient = MixiClient.new
  if mixiclient.login(params[:email], params[:password])
    @flash_mess = '正しいMixiのアカウント情報を確認できました。'
    @user_dao.mixi_regist params[:email], params[:password]
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

  if @user_dao.unregist
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

# 各種設定画面
get '/setting' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  user = @user_dao.get_settings
  params[:echo_twitter_url] = user.echo_twitter_url
  params[:hatena_id] = user.hatena_id
  params[:hatena_haiku_password] = user.hatena_haiku_password
  params[:gcal_mail] = user.gcal_mail
  params[:gcal_password] = user.gcal_password
  params[:gcal_feed_url] = user.gcal_feed_url

  erb :setting
end

post '/setting' do
  # 未ログインだったら/に戻す
  redirect '/' unless @login_flg
  # もし直リンクだったら/に戻す
  redirect '/' if session[:access_token] == '' || session[:secret_token] == ''

  echo_twitter_url = '0'
  echo_twitter_url = '1' if params[:echo_twitter_url]
  @user_dao.update_echo_twitter_url echo_twitter_url
  is_hatena_success = @user_dao.update_hatena_haiku_setting(params[:hatena_id], params[:hatena_haiku_password])
  
  # Gcal mail, pass, url保存
  is_gcal_success = @user_dao.update_gcal_setting(params)

  if (is_hatena_success == true)
    @flash_thank_mess = 'Twitter2mixi設定を更新しました。'
  else
    @flash_error_mess = 'Twitter2mixi設定を更新失敗しました。('
    @flash_error_mess += 'Hatena Haikuの設定が正しくありません' if is_hatena_success == false
    @flash_error_mess += ')'
  end

  erb :setting
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
