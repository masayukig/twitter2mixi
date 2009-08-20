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
    @user_dao.twitter_regist('29564476-Usq3GZQ1w38MWsHjUJrTvhPZgQa80F6cmAIpV7EQS', 'iRDppyEFP2gwpfDJ3B9vz1HGGrku3QZNGsixysxKxno').should == 1
    @user_dao.twitter_regist('test_token2', 'test_secret2').should == 2
    @batch.execute.should == be_true
  end
end

