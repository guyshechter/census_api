module CensusApi
  class Request
    
    require 'restclient'
    require 'hpricot'
    require 'json'
    require "yaml"
    
    attr_accessor :response
    
    @@census_shapes
    
    CENSUS_URL = "http://api.census.gov/data"

    def initialize(url, vintage, source, options)
      path = "#{url}/#{vintage}/#{source}?#{options.to_params}"
      @response = RestClient.get(path) do |response, request, result, &block|
        response
      end
      return @response
    end


    def self.find(source, options = {})
      fields = options[:fields]
      fields = fields.split(",").push("NAME").join(",") if fields.kind_of? String
      fields = fields.push("NAME").join(",") if fields.kind_of? Array
      params = { :key => options[:key], :get => fields, :for => format(options[:level],false) }
      params.merge!({ :in => format(options[:within][0],true) }) if !options[:within].empty?
      request = new(CENSUS_URL, options[:vintage], source, params)
      request.parse_response
    end

    
    def parse_response
      case @response.code
        when 200
          response = JSON.parse(@response)
          header = response.delete_at(0)
          return response.map{|r| Hash[header.map{|h| h.gsub("NAME","name")}.zip(r)]}
        else
          return {:code => @response.code, :message=> "Invalid API key or request", :location=> @response.headers[:location], :body => @response.body}
        end
    end
    
    protected
  
      def self.format(str,truncate)
        result = str.split("+").map{|s|
          if s.match(":")
            s = s.split(":")
          else 
            s = [s,"*"]
          end
          shp = shapes[s[0].upcase]
          s.shift && s.unshift(shp['name'].downcase.gsub(" ", "+")) if !shp.nil?
          s.unshift(s.shift.split("/")[0]) if !s[0].scan("home+land").empty? && truncate
          s.join(":")
        }
        return result.join("+")
      end 
      
      def self.shapes
        return  @@census_shapes if defined?( @@census_shapes)
        @@census_shapes = {} 
        YAML.load_file(File.dirname(__FILE__).to_s + '/../yml/census_shapes.yml').each{|k,v| @@census_shapes[k] = v}
        return @@census_shapes
      end
      
    end
  end

class Hash
   def to_params
     self.map { |k,v| "#{k}=#{v}" }.join("&")
   end
end
