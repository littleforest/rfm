# Connection object takes over the communication functionality that was previously in Rfm::Server.
# TODO: Clean up the way :grammar is sent in to the initializing method.
#       Currently, the actual connection instance config doesn't get set with the correct grammar,
#       even if the http_fetch is using the correct grammar.

require 'net/https'
require 'cgi'
module Rfm
# These have been moved to rfm.rb.
# 	SaxParser.default_class = CaseInsensitiveHash
# 	SaxParser.template_prefix = File.join(File.dirname(__FILE__), './sax/')
# 	SaxParser.templates.merge!({
# 		:fmpxmllayout => 'fmpxmllayout.yml',
# 		:fmresultset => 'fmresultset.yml',
# 		:fmpxmlresult => 'fmpxmlresult.yml',
# 		:none => nil
# 	})
	
  class Connection
  	include Config  	
  
		def initialize(action, params, request_options={},  *args)
    	config *args
      
      # Action sent to FMS
      @action = action
      # Query params sent to FMS
      @params = params
      # Additional options sent to FMS
      @request_options = request_options
      
      @defaults = {
        :host => 'localhost',
        #:port => 80,
        :proxy=>false,  # array of (p_addr, p_port = nil, p_user = nil, p_pass = nil)
        :ssl => true,
        :root_cert => true,
        :root_cert_name => '',
        :root_cert_path => '/',
        :account_name => '',
        :password => '',
        :log_actions => false,
        :log_responses => false,
        :log_parser => false,
        :warn_on_redirect => true,
        :raise_on_401 => false,
        :timeout => 60,
        :ignore_bad_data => false,
        :template => :fmresultset,
        :grammar => 'fmresultset'
      }   #.merge(options)
	
    end

    def state(*args)
    	@defaults.merge(super(*args))
    end
    
	  def host_name; state[:host]; end
	  def scheme; state[:ssl] ? "https" : "http"; end
	  def port; state[:ssl] && state[:port].nil? ? 443 : state[:port]; end

    def connect(action=@action, params=@params, request_options = @request_options, account_name=state[:account_name], password=state[:password])
    	grammar_option = request_options.delete(:grammar)
      post = params.merge(expand_options(request_options)).merge({action => ''})
      puts post
      puts post.inspect
      grammar = select_grammar(post, :grammar=>grammar_option)
      http_fetch(host_name, port, "/fmi/xml/#{grammar}.xml", account_name, password, post)
    end

    def select_grammar(post, options={})
			grammar = state(options)[:grammar] || 'fmresultset'
			if grammar.to_s.downcase == 'auto'
				# TODO: Build grammar parser in new sax engine templates to handle FMPXMLRESULT.
				return "fmresultset"
				post.keys.find(){|k| %w(-find -findall -dbnames -layoutnames -scriptnames).include? k.to_s} ? "FMPXMLRESULT" : "fmresultset"   
    	else
    		grammar
    	end
    end
    
    def parse(template=nil, initial_object=nil, parser=nil, options={})
    	template ||= state[:template]
    	#(template =  'fmresultset.yml') unless template
    	#(template = File.join(File.dirname(__FILE__), '../sax/', template)) if template.is_a? String
    	Rfm::SaxParser.parse(connect.body, template, initial_object, parser, state(*options)).result
    end




  private
  
    def http_fetch(host_name, port, path, account_name, password, post_data, limit=10)
      raise Rfm::CommunicationError.new("While trying to reach the Web Publishing Engine, RFM was redirected too many times.") if limit == 0
  
      if state[:log_actions] == true
        #qs = post_data.collect{|key,val| "#{CGI::escape(key.to_s)}=#{CGI::escape(val.to_s)}"}.join("&")
        qs_unescaped = post_data.collect{|key,val| "#{key.to_s}=#{val.to_s}"}.join("&")
        #warn "#{@scheme}://#{@host_name}:#{@port}#{path}?#{qs}"
        log.info "#{scheme}://#{host_name}:#{port}#{path}?#{qs_unescaped}"
      end
  
      request = Net::HTTP::Post.new(path)
      request.basic_auth(account_name, password)
      request.set_form_data(post_data)
  
  		if state[:proxy]
	  		connection = Net::HTTP::Proxy(*state[:proxy]).new(host_name, port)
  		else
	      connection = Net::HTTP.new(host_name, port)
	    end
      #ADDED LONG TIMEOUT TIMOTHY TING 05/12/2011
      connection.open_timeout = connection.read_timeout = state[:timeout]
      if state[:ssl]
        connection.use_ssl = true
        if state[:root_cert]
          connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
          connection.ca_file = File.join(state[:root_cert_path], state[:root_cert_name])
        else
          connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
  
      response = connection.start { |http| http.request(request) }
      if state[:log_responses] == true
        response.to_hash.each { |key, value| log.info "#{key}: #{value}" }
        log.info response.body
      end
  
      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPRedirection
        if state[:warn_on_redirect]
          log.warn "The web server redirected to " + response['location'] + 
          ". You should revise your connection hostname or fix your server configuration if possible to improve performance."
        end
        newloc = URI.parse(response['location'])
        http_fetch(newloc.host, newloc.port, newloc.request_uri, account_name, password, post_data, limit - 1)
      when Net::HTTPUnauthorized
        msg = "The account name (#{account_name}) or password provided is not correct (or the account doesn't have the fmxml extended privilege)."
        raise Rfm::AuthenticationError.new(msg)
      when Net::HTTPNotFound
        msg = "Could not talk to FileMaker because the Web Publishing Engine is not responding (server returned 404)."
        raise Rfm::CommunicationError.new(msg)
      else
        msg = "Unexpected response from server: #{response.code} (#{response.class.to_s}). Unable to communicate with the Web Publishing Engine."
        raise Rfm::CommunicationError.new(msg)
      end
    end
  
    def expand_options(options)
      result = {}
      field_mapping = options.delete(:field_mapping) || {}
      options.each do |key,value|
        case key.to_sym
        when :max_portal_rows
        	result['-relatedsets.max'] = value
        	result['-relatedsets.filter'] = 'layout'
        when :ignore_portals
        	result['-relatedsets.max'] = 0
        	result['-relatedsets.filter'] = 'layout'
        when :max_records
          result['-max'] = value
        when :skip_records
          result['-skip'] = value
        when :sort_field
          if value.kind_of? Array
            raise Rfm::ParameterError.new(":sort_field can have at most 9 fields, but you passed an array with #{value.size} elements.") if value.size > 9
            value.each_index { |i| result["-sortfield.#{i+1}"] = field_mapping[value[i]] || value[i] }
          else
            result["-sortfield.1"] = field_mapping[value] || value
          end
        when :sort_order
          if value.kind_of? Array
            raise Rfm::ParameterError.new(":sort_order can have at most 9 fields, but you passed an array with #{value.size} elements.") if value.size > 9
            value.each_index { |i| result["-sortorder.#{i+1}"] = value[i] }
          else
            result["-sortorder.1"] = value
          end
        when :post_script
          if value.class == Array
            result['-script'] = value[0]
            result['-script.param'] = value[1]
          else
            result['-script'] = value
          end
        when :pre_find_script
          if value.class == Array
            result['-script.prefind'] = value[0]
            result['-script.prefind.param'] = value[1]
          else
            result['-script.presort'] = value
          end
        when :pre_sort_script
          if value.class == Array
            result['-script.presort'] = value[0]
            result['-script.presort.param'] = value[1]
          else
            result['-script.presort'] = value
          end
        when :response_layout
          result['-lay.response'] = value
        when :logical_operator
          result['-lop'] = value
        when :modification_id
          result['-modid'] = value
        else
          raise Rfm::ParameterError.new("Invalid option: #{key} (are you using a string instead of a symbol?)")
        end
      end
      return result
    end  
  
  end # Connection

  
end # Rfm
