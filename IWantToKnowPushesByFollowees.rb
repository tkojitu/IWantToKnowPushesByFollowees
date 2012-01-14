require 'json'
require 'net/https'
require 'open-uri'
require 'pp'

class IWantToKnowPushesByFollowees
  def doit(user)
    events = []
    start_api do |access|
      urls = get_following_urls(user, access)
      events = get_push_events(access, urls)
    end
    events.each do |event|
      $stdout.printf("%s %s %s %s\n", event['actor']['login'], event['type'],
                     event['repo']['url'], event['created_at'])
    end
  end

  def get_following_urls(user, access)
    urls = []
    page_number = 1
    while true
      urls_page = get_urls_by_page(user, access, page_number)
      urls_page.empty? && break
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

  def get_urls_by_page(user, access, page_number)
    followings = get_followings_by_page(user, access, page_number)
    return followings.collect{|f| f['url']}
  end

  def get_followings_by_page(user, access, page_number)
    path = sprintf('/users/%s/following?page=%d', user, page_number)
    response = access.get(path)
    return JSON.load(response.body)
  end

  def get_push_events(access, urls)
    events = []
    urls.each do |url|
      public_events = get_public_events(access, url)
      public_events.delete_if{|event| event['type'] != 'PushEvent'}
      !public_events.empty? && events.concat(public_events)
    end
    return events
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
