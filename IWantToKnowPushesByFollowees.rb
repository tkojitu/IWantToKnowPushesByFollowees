require 'date'
require 'json'
require 'net/https'
require 'open-uri'
require 'pp'

module IWantToKnowPushesByFollowees
  class Accessor
    def doit(user)
      filter = EventFilter.new
      Printer.new.print_all do |printer|
        each_following_public_event(user) do |event|
          filter.filter(event) do |event|
            printer.print(event)
          end
        end
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

  class Printer
    def print_all #block
      print_head
      yield self
      print_foot
    end

    def print_head
      puts('<html>')
      puts('<body>')
    end

    def print(event)
      templ = "<p div='event'>%s %s %s %s\n</p>"
      link = url_to_link(event['repo']['url'])
      $stdout.printf(templ, event['actor']['login'], event['type'],
                     link, event['created_at'])
    end

    def url_to_link(url)
      return sprintf("<a href='%s'>%s</a>", url, File.basename(url))
    end

    def datestr_to_date(date)
      time = DateTime::parse(date)
      return time.iso8601
    end

    def print_foot
      puts('</body>')
      puts('</html>')
    end
  end

  class EventFilter
    def filter(event) #block
      event['type'] != 'PushEvent' && return
      time = DateTime::parse(event['created_at'])
      now = DateTime.now
      now.to_time - time.to_time > 60.0 * 60 * 24 * 7 && return
      yield event
    end
  end
end

if $0 == __FILE__
  app = IWantToKnowPushesByFollowees::Accessor.new('tkojitu')
  app.doit('tkojitu')
end
