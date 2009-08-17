require 'rubygems'
require 'twitter_oauth'
require 'kconv'

  @@config = YAML.load_file("config.yml") rescue nil || {}
 
  token = '29564476-Usq3GZQ1w38MWsHjUJrTvhPZgQa80F6cmAIpV7EQS'
  secret = 'iRDppyEFP2gwpfDJ3B9vz1HGGrku3QZNGsixysxKxno'

  @client = TwitterOAuth::Client.new(
    :consumer_key => @@config['consumer_key'],
    :consumer_secret => @@config['consumer_secret'],
    :token => token,
    :secret => secret
  )

#  @access_token = @client.authorize(token, secret)
p @client.authorized?
print @client.info

  @tweets = @client.user

#print @tweets
