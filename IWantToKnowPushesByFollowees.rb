#!ruby
require 'cgi'
require 'date'
require 'json'
require 'net/https'

module IWantToKnowPushesByFollowees
  class Accessor
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
    def initialize(output=$stdout)
      @output = output
    end

    def print_all #block
      print_head
      yield self
      print_foot
    end

    def print_head
      @output.puts('<html>')
      @output.puts('<body>')
    end

    def print(event)
      templ = "<p>%s %s %s at %s\n</p>"
      actor_link = actor_url_to_link(event['actor']['url'])
      verb = event_to_verb(event)
      repo_link = repo_url_to_link(event['repo']['url'])
      date = event['created_at'].gsub(/[TZ]/, ' ')
      @output.printf(templ, actor_link, verb, repo_link, date)
    end

    def event_to_verb(event)
      case event['type']
      when 'PushEvent'
        return 'pushed'
      else
        return 'dit something'
      end
    end

    def actor_url_to_link(url)
      str = url.sub(/api\./, '')
      str = str.sub(/\/users\//, '/')
      return url_to_link(str)
    end

    def repo_url_to_link(url)
      str = url.sub(/api\./, '')
      str = str.sub(/\/repos\//, '/')
      return url_to_link(str)
    end

    def url_to_link(url)
      return sprintf("<a href='%s'>%s</a>", url, File.basename(url))
    end

    def datestr_to_date(date)
      time = DateTime::parse(date)
      return time.iso8601
    end

    def print_foot
      @output.puts('</body>')
      @output.puts('</html>')
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

  class WebApp
    def initialize(cgi)
      @cgi = cgi
    end

    def main
      print_http_header
      user = get_user
      print_html(user)
    end

    def print_http_header
      $stdout.print("Content-Type: text/html; charset=UTF-8\r\n\r\n")
    end

    def get_user
      return @cgi.has_key?('user') ? @cgi['user'] : 'tkojitu'
    end

    def print_html(user)
      acc = Accessor.new
      filter = EventFilter.new
      Printer.new($stdout).print_all do |printer|
        acc.each_following_public_event(user) do |event|
          filter.filter(event) do |event|
            printer.print(event)
          end
        end
      end
    end
  end

  def desktop_main
    acc = Accessor.new
    filter = EventFilter.new
    Printer.new.print_all do |printer|
      acc.each_following_public_event(ARGV[0]) do |event|
        filter.filter(event) do |event|
          printer.print(event)
        end
      end
    end
  end
end

if ENV['SCRIPT_FILENAME'] &&
    File.basename(ENV['SCRIPT_FILENAME']) == File.basename(__FILE__)
  include IWantToKnowPushesByFollowees
  WebApp.new(CGI.new).main
elsif $0 == __FILE__
  include IWantToKnowPushesByFollowees
  desktop_main
end
