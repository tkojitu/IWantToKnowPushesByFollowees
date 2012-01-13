require 'json'
require 'net/https'
require 'open-uri'

class IWantToKnowPushesByFollowees
  def initialize(follower)
    @follower = follower
  end

  def get_urls
    start_api do |https|
      return get_following_urls(https)
    end
  end

  def get_following_urls(https)
    urls = []
    page_number = 1
    while true
      urls_page = get_urls_by_page(https, page_number)
      break if urls_page.empty?
      urls.concat(urls_page)
      page_number += 1
    end
    return urls
  end

  def start_api #block
    https = Net::HTTP.new('api.github.com', 443)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_PEER
    https.verify_depth = 5
    https.start do |h|
      yield h
    end
  end

  def get_urls_by_page(https, page_number)
    followings = get_followings_by_page(https, page_number)
    return followings.collect{|f| f['url']}
  end

  def get_followings_by_page(https, page_number)
    path = sprintf('/users/%s/following?page=%d', @follower, page_number)
    response = https.get(path)
    return JSON.load(response.body)
  end
end

if $0 == __FILE__
  app = IWantToKnowPushesByFollowees.new('tkojitu')
  p app.get_urls[0]
end
