require 'spec/spec_helper'
require 'lib/user_dao'

describe 'UserDaoの仕様' do
  before(:each) do
    # コンフィグ情報読込
    @config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')
    @user_dao = UserDao.new @config
  end

  it '正しい値での会員の新規登録できTrueを返し、ログイン状態になる' do
    @user_dao.login_flg.should be_false
    @user_dao.twitter_regist('test_token', 'test_secret').should be_true
    @user_dao.login_flg.should be_true
  end

  it '重複登録があってもTrueを返し、ログイン状態になる' do
    @user_dao.login_flg.should be_false
    @user_dao.twitter_regist('test_token', 'test_secret').should == 1
    @user_dao.login_flg.should be_true
    @user_dao.twitter_regist('test_token', 'test_secret').should == 1
    @user_dao.login_flg.should be_true
    @user_dao.twitter_regist('test_token1', 'test_secret').should == 2
    @user_dao.login_flg.should be_true
  end

  it 'ログインしてない時にMixi会員アカウントを設定するとFlaseを返す' do
    @user_dao.mixi_regist('test_token', 'test_secret').should be_false
  end

  it 'ログインしている時にMixi会員アカウントを設定するとTrueを返す' do
    # 会員登録
    @user_dao.twitter_regist('test_token', 'test_secret').should == 1
    # ログイン
    @user_dao.login('test_token', 'test_secret').should == 1
    # Mixiアカウント登録
    @user_dao.mixi_regist('mixi@gmail.com', 'mixipass').should be_true
  end

  it '正しくない値(Eメールエラー)での会員の新規登録でエラーとなりfalseを返す'
  it '正しくない値(EメールがNil)での会員の新規登録でエラーとなりfalseを返す'
  it '正しくない値(パスワードがNil)で会員の新規登録でエラーとなりfalseを返す'
  it '正しいトークンとシークレットでログイン状態となりユーザ情報を取得できる'
  it '正しくないトークンとシークレットではログインが失敗しnilが返ってくる'

  it ''
  it ''
  it ''

end

