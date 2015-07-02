require "net/http"
require "uri"
require 'nokogiri'
require 'awesome_print'
require 'logger'

class Crawler

  def initialize url
    find_base_url(url)
    @report_file = File.open("logs/#{@uri.host}.report.log", 'w+')
    @logger_err = Logger.new("logs/#{@uri.host}.error.log")
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @links = {}
    @results = []
    @error_count = 0
  end

  def add_link path, origin
    path.gsub!(Regexp.new("^#{@base_url}"), "")
    path.gsub('\"')
    unless path.match(/^$|^#|^http|^mailto|\/redirect\?goto/) || (@results.include?(path))      
      @links[path] = [] unless @links[path] 
      @links[path] << origin 
    end
  end

  def parse path, origins, get_links=false
    uri = URI.parse(path)
    request = Net::HTTP::Get.new(path)
    response = @http.request(request)
    code = response.code.to_i
    @results << path if code < 400
    if get_links
      if code < 400                
        doc = Nokogiri::HTML(response.body)
        doc.css('a').each do |node|
          # insert the link        
          link = node['href']
          next unless link
          add_link link, path             
        end
        puts "parsed #{path}"
      else 
        puts "failed #{path}"
        @error_count = +1
        @logger_err.error "#{code}: #{path}"
        @logger_err.error "    COMING FROM: #{origins.join(' , ')}"
      end 
    end
  end

  def go
    parse '/', [], true
    puts  "Level 1: found #{@links.count} links: parsing its"
    @links.clone.each do |link, origins|
      @links.delete link
      parse link, origins, true
    end
    puts "Level 2: found #{@links.count} links: parsing its"
    remaining = @links.count 

    @links.clone.each do |link, origins|
      remaining = remaining - 1
      puts "#{remaining} remaining links: doing #{link}"
      @links.delete link
      parse link, origins
    end

    @report_file.write "SUCCESS: #{@results.count} - ERRORS: #{@error_count}\n"
    @results.sort!  
    @results.each do |url|
      @report_file.write "#{url}\n"
      puts url
    end
    @report_file.close
  end

  private
    def find_base_url(base_url)
      uri = URI.parse(base_url)
      request = Net::HTTP::Get.new('/')
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.request(request)
      code = response.code.to_i
      if code == 301 || code == 302
        find_base_url response.header['location']
      else
        @base_url = base_url
        @http = http
        @uri = uri
      end
    end
end

#Crawler.new('http://nick-1.nick.de').go
@domain = ARGV[0]
Crawler.new("http://#{@domain}").go


