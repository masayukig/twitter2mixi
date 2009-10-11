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
#    @user_dao.last_status = 'こんにちは！'
#    @user_dao.last_status = 'twilog.org ユーザになりました。@ropross さん、素晴らしいです！ http://twitpic.com/ez1le'


    @user_dao.twitter_regist('test_token2', 'test_secret2').should == 2
    @batch.main(@config['max_thread_number']).should be_true
    @batch.main(@config['max_thread_number']).should be_true
    # TODO MixiEchoへ二重で投稿されていないという確認のテストコード作成
  end

  it "ユーザを1000人追加してバッチ処理を実行。ユーザ情報を抜け漏れ重複なく取得出来たことを確認する" do
    for no in 1..1000
      @user_dao.twitter_regist("test_token#{no}", "test_secret#{no}").should == no
      @user_dao.mixi_regist("test_mail_#{no}", "test_pass_#{no}").should be_true
    end
    puts "test user added."
    @batch.main(@config['max_thread_number']).should be_true
    puts "executed user:#{@batch.user_count}"
    @batch.user_count.should == 1000
  end

end

