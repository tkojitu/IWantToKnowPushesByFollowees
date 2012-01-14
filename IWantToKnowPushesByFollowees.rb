require 'json'
require 'net/https'
require 'open-uri'
require 'pp'

class IWantToKnowPushesByFollowees
  def doit(user)
    each_following_public_event(user) do |event|
      event['type'] != 'PushEvent' && next
      $stdout.printf("%s %s %s %s\n", event['actor']['login'], event['type'],
                     event['repo']['url'], event['created_at'])
    end
  end

  def each_following_public_event(user) #block
    start_api do |access|
      each_following_url(user, access) do |url|
        each_public_event(access, url) do |event|
          yield event
        end
      end
    end
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

  def each_following_url(user, access) #block
    page_number = 1
    while true
      urls = get_urls_by_page(user, access, page_number)
      urls.empty? && break
      urls.each{|url| yield url}
      page_number += 1
    end
  end

  def get_urls_by_page(user, access, page_number)
    followings = get_followings_by_page(user, access, page_number)
    return followings.collect{|f| f['url']}
  end

  def get_followings_by_page(user, access, page_number)
    path = sprintf('/users/%s/following?page=%d', user, page_number)
    response = access.get(path)
    return JSON.load(response.body)
  end

  def each_public_event(access, url) #block
    events = get_public_events(access, url)
    events.each{|event| yield event}
  end

  def get_public_events(access, url)
    path = url + '/events/public'
    response = access.get(path)
    return JSON.load(response.body)
  end
end

if $0 == __FILE__
  app = IWantToKnowPushesByFollowees.new('tkojitu')
  app.doit('tkojitu')
end
