require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'lib/user_dao'
require 'lib/batch'

describe Batch do
  before(:each) do
    # コンフィグ情報読込
    @config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/../config.yml')
    @user_dao = UserDao.new @config
    @user_dao.db_init
    @batch = Batch.new @config
  end

  it "ユーザを2人追加してバッチ処理を実行をしてTrueが返り正常終了" do
    # 会員登録
    @user_dao.twitter_regist(@config['twitter_token'], @config['twitter_secret']).should == 1
    @user_dao.mixi_regist(@config['mixiemail'], @config['mixipassword']).should be_true
    @user_dao.last_status = '半月前から『おじさん』になりました！姉の赤ちゃん^^ カワイイ！ http://twitpic.com/eu3gb'
#    @user_dao.last_status = 'twilog.org ユーザになりました。@ropross さん、素晴らしいです！ http://twitpic.com/ez1le'


    #    @user_dao.twitter_regist('test_token2', 'test_secret2').should == 2
    @batch.execute.should be_true
    @batch.execute.should be_true
    # TODO MixiEchoへ二重で投稿されていないという確認のテストコード作成
  end
end

