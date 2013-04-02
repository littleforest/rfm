module Rfm
  # The Layout object represents a single FileMaker Pro layout. You use it to interact with 
  # records in FileMaker. *All* access to FileMaker data is done through a layout, and this
  # layout determines which _table_ you actually hit (since every layout is explicitly associated
  # with a particular table -- see FileMakers Layout->Layout Setup dialog box). You never specify
  # _table_ information directly in RFM.
  #
  # Also, the layout determines which _fields_ will be returned. If a layout contains only three
  # fields from a large table, only those three fields are returned. If a layout includes related
  # fields from another table, they are returned as well. And if the layout includes portals, all
  # data in the portals is returned (see Record::portal for details).
  #
  # As such, you can _significantly_ improve performance by limiting what you put on the layout.
  #
  # =Using Layouts
  #
  # The Layout object is where you get most of your work done. It includes methods for all
  # FileMaker actions:
  # 
  # * Layout::all
  # * Layout::any
  # * Layout::find
  # * Layout::edit
  # * Layout::create
  # * Layout::delete
  #
  # =Running Scripts
  # 
  # In FileMaker, execution of a script must accompany another action. For example, to run a script
  # called _Remove Duplicates_ with a found set that includes everybody
  # named _Bill_, do this:
  #
  #   myLayout.find({"First Name" => "Bill"}, :post_script => "Remove Duplicates")
  #
  # ==Controlling When the Script Runs
  #
  # When you perform an action in FileMaker, it always executes in this order:
  # 
  # 1. Perform any find
  # 2. Sort the records
  # 3. Return the results
  #
  # You can control when in the process the script runs. Each of these options is available:
  #
  # * *post_script* tells FileMaker to run the script after finding and sorting
  # * *pre_find_script* tells FileMaker to run the script _before_ finding
  # * *pre_sort_script* tells FileMaker to run the script _before_ sorting, but _after_ finding
  #
  # ==Passing Parameters to a Script
  # 
  # If you want to pass a parameter to the script, use the options above, but supply an array value
  # instead of a single string. For example:
  #
  #   myLayout.find({"First Name" => "Bill"}, :post_script => ["Remove Duplicates", 10])
  #
  # This sample runs the script called "Remove Duplicates" and passes it the value +10+ as its 
  # script parameter.
  #
  # =Common Options
  # 
  # Most of the methods on the Layout object accept an optional hash of +options+ to manipulate the
  # action. For example, when you perform a find, you will typiclaly get back _all_ matching records. 
  # If you want to limit the number of records returned, you can do this:
  #
  #   myLayout.find({"First Name" => "Bill"}, :max_records => 100)
  # 
  # The +:max_records+ option tells FileMaker to limit the number of records returned.
  #
  # This is the complete list of available options:
  # 
  # * *max_records* tells FileMaker how many records to return
  #
  # * *skip_records* tells FileMaker how many records in the found set to skip, before
  #   returning results; this is typically combined with +max_records+ to "page" through 
  #   records
  #
  # * *sort_field* tells FileMaker to sort the records by the specified field
  # 
  # * *sort_order* can be +descend+ or +ascend+ and determines the order
  #   of the sort when +sort_field+ is specified
  #
  # * *post_script* tells FileMaker to perform a script after carrying out the action; you 
  #   can pass the script name, or a two-element array, with the script name first, then the
  #   script parameter
  #
  # * *pre_find_script* is like +post_script+ except the script runs before any find is 
  #   performed
  #
  # * *pre_sort_script* is like +pre_find_script+ except the script runs after any find
  #   and before any sort
  # 
  # * *response_layout* tells FileMaker to switch layouts before producing the response; this
  #   is useful when you need a field on a layout to perform a find, edit, or create, but you
  #   want to improve performance by not including the field in the result
  #
  # * *logical_operator* can be +and+ or +or+ and tells FileMaker how to process multiple fields
  #   in a find request
  # 
  # * *modification_id* lets you pass in the modification id from a Record object with the request;
  #   when you do, the action will fail if the record was modified in FileMaker after it was retrieved
  #   by RFM but before the action was run
  #
  #
  # =Attributes
  #
  # The Layout object has a few useful attributes:
  #
  # * +name+ is the name of the layout
  #
  # * +field_controls+ is a hash of FieldControl objects, with the field names as keys. FieldControl's
  #   tell you about the field on the layout: how is it formatted and what value list is assigned
  #
  # Note: It is possible to put the same field on a layout more than once. When this is the case, the
  # value in +field_controls+ for that field is an array with one element representing each instance
  # of the field.
  # 
  # * +value_lists+ is a hash of arrays. The keys are value list names, and the values in the hash
  #   are arrays containing the actual value list items. +value_lists+ will include every value
  #   list that is attached to any field on the layout
  
  class Layout
	  include Config
		    
    # Initialize a layout object. You never really need to do this. Instead, just do this:
    # 
    #   myServer = Rfm::Server.new(...)
    #   myDatabase = myServer["Customers"]
    #   myLayout = myDatabase["Details"]
    #
    # This sample code gets a layout object representing the Details layout in the Customers database
    # on the FileMaker server.
    # 
    # In case it isn't obvious, this is more easily expressed this way:
    #
    #   myServer = Rfm::Server.new(...)
    #   myLayout = myServer["Customers"]["Details"]
    def initialize(*args) #name, db_obj
    	options = get_config(*args)
    	rfm_metaclass.instance_variable_set :@db, (options[:objects].delete_at(0) || options[:database_object])
    	config :parent=> 'db'
    	options = get_config(options)
    	
    	config sanitize_config(options, {}, true)
    	config :layout => options[:strings].delete_at(0) || options[:layout]
    
    	raise Rfm::Error::RfmError.new(0, "New instance of Rfm::Layout has no name. Attempted name '#{state[:layout]}'.") if state[:layout].to_s == ''
                  
      @loaded = false
      @field_controls = Rfm::CaseInsensitiveHash.new
      @value_lists = Rfm::CaseInsensitiveHash.new
			#	@portal_meta = nil
			#	@field_names = nil
			#@ignore_bad_data = (db_obj.server.state[:ignore_bad_data] rescue nil)
    end
    
    meta_attr_reader :db
    attr_reader :field_mapping
    attr_writer :field_names, :portal_meta, :table
    def_delegator :db, :server
    alias_method :database, :db
		
		# This method may be obsolete, since the option can now be set with #config.
    def ignore_bad_data(val = nil)
    	(config :ignore_bad_data => val) unless val.nil?
    	state[:ignore_bad_data]
    end
    
    # These methods are to be inclulded in Layout and SubLayout, so that
    # they have their own discrete 'self' in the master class and the subclass.
    # This means these methods will not get forwarded, and will talk to the correct
    # variables & objects of the correct self.
    # Do not get or set instance variables in Layout from other objects directly,
    # always use getter & setter methods.
    # This all means that any chain of methods that want to refer ultimately to Sublayout, must all be defined or included in Sublayout
    module LayoutModule
    
	    # Returns a ResultSet object containing _every record_ in the table associated with this layout.
	    def all(options = {})
	      get_records('-findall', {}, options)
	    end
	    
	    # Returns a ResultSet containing a single random record from the table associated with this layout.
	    def any(options = {})
	      get_records('-findany', {}, options)
	    end
	  
	    # Finds a record. Typically you will pass in a hash of field names and values. For example:
	    #
	    #   myLayout.find({"First Name" => "Bill"})
	    #
	    # Values in the hash work just like value in FileMaker's Find mode. You can use any special
	    # symbols (+==+, +...+, +>+, etc...).
	    #
			# Create a Filemaker 'omit' request by including an :omit key with a value of true.
			# 
			# 	myLayout.find :field1 => 'val1', :field2 => 'val2', :omit => true
			# 
			# Create multiple Filemaker find requests by passing an array of hashes to the #find method.
			# 
			# 	myLayout.find [{:field1 => 'bill', :field2 => 'admin'}, {:field3 => 'inactive', :omit => true}, ...]
			# 
			# If the value of a field in a find request is an array of strings, the string values will be logically OR'd in the query.
			# 
			# 	myLayout.find :fieldOne => ['bill','mike','bob'], :fieldTwo =>'staff'	    
	    #
	    # If you pass anything other than a hash or an array as the first parameter, it is converted to a string and
	    # assumed to be FileMaker's internal id for a record (the recid).
	    #
	    #   myLayout.find 54321
	    #
	    def find(find_criteria, options = {})
	    	#puts "layout.find-#{self.object_id}"
	    	options.merge!({:field_mapping => field_mapping}) if field_mapping
				get_records(*Rfm::CompoundQuery.new(find_criteria, options))
	    end
	    
	    # Access to raw -findquery command.
	    def query(query_hash, options = {})
	    	get_records('-findquery', query_hash, options)
	    end
	  
	    # Updates the contents of the record whose internal +recid+ is specified. Send in a hash of new
	    # data in the +values+ parameter. Returns a RecordSet containing the modified record. For example:
	    #
	    #   recid = myLayout.find({"First Name" => "Bill"})[0].record_id
	    #   myLayout.edit(recid, {"First Name" => "Steve"})
	    #
	    # The above code would find the first record with _Bill_ in the First Name field and change the 
	    # first name to _Steve_.
	    def edit(recid, values, options = {})
	      get_records('-edit', {'-recid' => recid}.merge(values), options)
	      #get_records('-edit', {'-recid' => recid}.merge(expand_repeats(values)), options) # attempt to set repeating fields.
	    end
	    
	    # Creates a new record in the table associated with this layout. Pass field data as a hash in the 
	    # +values+ parameter. Returns the newly created record in a RecordSet. You can use the returned
	    # record to, ie, discover the values in auto-enter fields (like serial numbers). 
	    #
	    # For example:
	    #
	    #   result = myLayout.create({"First Name" => "Jerry", "Last Name" => "Robin"})
	    #   id = result[0]["ID"]
	    #
	    # The above code adds a new record with first name _Jerry_ and last name _Robin_. It then
	    # puts the value from the ID field (a serial number) into a ruby variable called +id+.
	    def create(values, options = {})
	      get_records('-new', values, options)
	    end
	    
	    # Deletes the record with the specified internal recid. Returns a ResultSet with the deleted record.
	    #
	    # For example:
	    #
	    #   recid = myLayout.find({"First Name" => "Bill"})[0].record_id
	    #   myLayout.delete(recid)
	    # 
	    # The above code finds every record with _Bill_ in the First Name field, then deletes the first one.
	    def delete(recid, options = {})
	      get_records('-delete', {'-recid' => recid}, options)
	      return nil
	    end
	    
	    # Retrieves metadata only, with an empty resultset.
	    def view(options = {})
	    	get_records('-view', {}, options)
	    end
	    
	    def get_records(action, extra_params = {}, options = {})
	    	# TODO: The grammar stuff here won't work properly until you handle config between
	    	# models/sublayouts/layout/server (Is this done now?).
	    	grammar_option = state(options)[:grammar]
	    	options.merge!(:grammar=>grammar_option) if grammar_option
	      #include_portals = options[:include_portals] ? options.delete(:include_portals) : nil
	      include_portals = !options[:ignore_portals]
	      
	      # Apply mapping from :field_mapping, to send correct params in URL.
	      prms = params.merge(extra_params)
	      map = field_mapping.invert
	      # TODO: Make this part handle string AND symbol keys.
	      #map.each{|k,v| prms[k]=prms.delete(v) if prms[v]}
	      prms.dup.each_key{|k| prms[map[k.to_s]]=prms.delete(k) if map[k.to_s]}
	      
	      xml_response = server.connect(state[:account_name], state[:password], action, prms, options).body
	      Rfm::Resultset.new(xml_response, self, include_portals)
	    end
	    
	    def params
	      {"-db" => db.name, "-lay" => self.name}
	    end
	    			
			
			# Intended to set each repeat individually but doesn't work with FM
			def expand_repeats(hash)
				hash.each do |key,val|
					if val.kind_of? Array
						val.each_with_index{|v, i| hash["#{key}(#{i+1})"] = v}
						hash.delete(key)
					end
				end
				hash
			end
			
			# Intended to brute-force repeat setting but doesn't work with FM
			def join_repeats(hash)
				hash.each do |key,val|
					if val.kind_of? Array
						hash[key] = val.join('\x1D')
					end
				end
				hash
			end

	    def name; state[:layout].to_s; end
	    
			def state(*args)
				get_config(*args)
			end

	  end # LayoutModule
	  
	  include LayoutModule
	  
	  
    ###
		def view_meta
			@view_meta ||= view
		end
		def date_format
			@date_format ||= view_meta.date_format
		end
		def time_format
			@time_format ||= view_meta.time_format
		end		
		def timestamp_format
			@timestamp_format ||= view_meta.timestamp_format
		end
		def field_meta
			@field_meta ||= view_meta.field_meta
		end
		###
    
    
    def field_controls
      load unless @loaded
      @field_controls
    end
    
  	def field_names
  		load unless @field_names
  		@field_names
  	end
  	
  	def field_names_no_load
  		@field_names
  	end
    
    def value_lists
      load unless @loaded
      @value_lists
    end
    
    def count(find_criteria, options={})
    	find(find_criteria, options.merge({:max_records => 0})).foundset_count
    end
    
  	def total_count
  		view.total_count
  	end
  	
  	def portal_meta
  		@portal_meta ||= view.portal_meta
  	end
  	
  	def portal_meta_no_load
  		@portal_meta
  	end
  	
  	def portal_names
  		portal_meta.keys
  	end
  	
  	def table
  		@table ||= view.table
  	end
  	
  	def table_no_load
  		@table
  	end
    
    def load
      @loaded = true
      fmpxmllayout = db.server.load_layout(self)
      doc = XmlParser.new(fmpxmllayout.body, :namespace=>false, :parser=>server.state[:parser])
      
      # check for errors
      error = doc['FMPXMLLAYOUT']['ERRORCODE'].to_s.to_i
      raise Rfm::Error::FileMakerError.getError(error) if error != 0
      
      # process valuelists
      vlists = [doc['FMPXMLLAYOUT']['VALUELISTS']['VALUELIST']].flatten
      puts vlists.to_yaml #REMOVE#
      if !vlists.nil?    #root.elements['VALUELISTS'].size > 0
        vlists.each {|valuelist|
        	puts valuelist.to_yaml #REMOVE#
          name = valuelist['NAME']
          @value_lists[name] = [valuelist['VALUE']].flatten.collect{|value|
          	Rfm::Metadata::ValueListItem.new(value['__content__'], value['DISPLAY'], name)
          } rescue []
        }
        @value_lists.freeze
      end

      # process field controls
      [doc['FMPXMLLAYOUT']['LAYOUT']['FIELD']].flatten.each {|field|
        name = field_mapping[field['NAME']] || field['NAME']
        style = field['STYLE']
        type = style['TYPE']
        value_list_name = style['VALUELIST']
        value_list = @value_lists[value_list_name] if value_list_name != ''
        field_control = Rfm::Metadata::FieldControl.new(name, type, value_list_name, value_list)
        existing = @field_controls[name]
        if existing
          if existing.kind_of?(Array)
            existing << field_control
          else
            @field_controls[name] = Array[existing, field_control]
          end
        else
          @field_controls[name] = field_control
        end
      }
      @field_names ||= @field_controls.collect{|k,v| v.name rescue v[0].name}
      @field_controls.freeze
    end
    
		def field_mapping
			@field_mapping ||= load_field_mapping(get_config[:field_mapping])
		end
		
		def load_field_mapping(mapping={})
			mapping = (mapping || {}).to_cih
			def mapping.invert
				super.to_cih
			end
			mapping
		end
    
  	private :load, :get_records, :params
      
      
  end # Layout
end # Rfm