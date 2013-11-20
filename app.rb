require 'sinatra'
require 'csv'
require 'digest/md5'
require 'base64'
require 'literate_randomizer'
require 'twitter'
require 'uri'

configure do
  set :wallet, '1C7TVHUTLkj4MYqjyqXyKEiWo1mvaBwPtW'
  set :cache, {}
  set :tweets, {}
  set :headlines, CSV.read(File.join(settings.root, "headlines.csv"), headers: true)["Text"].concat([
      "Spinning Newspaper Injures Printer",
      "Squirrel Resembling Abraham Lincoln Found",
      "Cosmetics Scare In Gotham"
    ])


  if ["TWITTER_CONSUMER_KEY","TWITTER_CONSUMER_SECRET",
    "TWITTER_ACCESS_TOKEN","TWITTER_ACCESS_SECRET"].all? {|k| ENV.has_key?(k) }
    enable :twitter_client
  else
    disable :twitter_client
  end

  if settings.twitter_client?
    set :twitter, Twitter::Client.new(
      consumer_key:        ENV["TWITTER_CONSUMER_KEY"],
      consumer_secret:     ENV["TWITTER_CONSUMER_SECRET"],
      access_token:        ENV["TWITTER_ACCESS_TOKEN"],
      access_token_secret: ENV["TWITTER_ACCESS_SECRET"]
    )
  end
end

get '/' do
  headline = (params[:q] || settings.headlines.sample).strip

  if params[:q]
    if t = twitter_uri_or_headline(headline)
      redirect to("/t/#{t}")
    else
      redirect to("/#{Base64.urlsafe_encode64(headline)}")
    end
  else
    render_frontpage headline
  end
end

get '/:permalink' do
  headline = Base64.urlsafe_decode64(params[:permalink])
  frontpage_from_cache(headline)
end

get '/t/:id' do
  if settings.twitter_client?
    begin
      frontpage_from_tweet settings.twitter.status(params[:id])
    rescue Twitter::Error::ClientError => e
      halt 400, e.message
    end
  else
    halt
  end
end

def render_frontpage(headline, checksum = nil, options = {})
  checksum ||= Digest::MD5.hexdigest(headline)

  erb :paper, locals: {
    headline: ERB::Util.html_escape(headline),
    checksum: checksum,
    date: options[:date] || Date.today,
    image: options[:image]|| "http://www.avatarpro.biz/avatar/#{checksum}?s=120",
    wallet: settings.wallet,
    permalink: options[:permalink] || "/#{Base64.urlsafe_encode64(headline)}",
    paragraphs: LiterateRandomizer.paragraphs(join: false, paragraphs: 12..18)
  }
end

def frontpage_from_cache(headline)
  checksum = Digest::MD5.hexdigest(headline)
  settings.cache.fetch(checksum) do |sum|
    settings.cache[sum] = render_frontpage(headline, sum)
  end
end

def frontpage_from_tweet(tweet)
  headline = tweet.full_text
  checksum = Digest::MD5.hexdigest(headline)
  settings.tweets.fetch(tweet.id.to_s(16)) do |hex|
    settings.tweets[hex] = render_frontpage(headline, checksum, {
      date: tweet.created_at,
      image: tweet.user.profile_image_url(:bigger),
      permalink: "http://twitter.com/#{tweet.user.screen_name}/status/#{tweet.id}"
    })
  end
end

def twitter_uri_or_headline(query)
  u = URI.parse(query)
  return false unless u.is_a?(URI::HTTP) and u.hostname.match(/\A(www\.)?twitter\.com/)

  /^\/\w+\/status\/(\d+)$/.match(u.path) do |match|
    match[1]
  end
rescue URI::InvalidURIError => e
  false
end

