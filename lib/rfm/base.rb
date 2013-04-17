module Rfm
	#
	# Adds ability to create Rfm::Base model classes that behave similar to ActiveRecord::Base models.
	# If you set your Rfm.config (or RFM_CONFIG) with your host, database, account, password, and
	# any other server/database options, you can provide your models with nothing more than a layout.
	#
	# 	class Person < Rfm::Base
	# 	  config :layout => 'mylayout'
	# 	end
	#
	# And similar to ActiveRecord, you can define callbacks, validations, attributes, and methods on your model.
	#   (if you have ActiveModel loaded).
	#
	#   class Account < Rfm::Base
	#     config :layout=>'account_xml'
	#     before_create :encrypt_password
	#     validates :email, :presence => true
	#     validates :username, :presence => true
	#     attr_accessor :password
	#   end
	#   
	# Then in your project, you can use these models just like ActiveRecord models.
	# The query syntax and options are still Rfm under the hood. Treat your model
	# classes like Rfm::Layout objects, with a few enhancements.
	#
	#   @account = Account.new :username => 'bill', :password => 'pass'
	#   @account.email = 'my@email.com'
	#   @account.save!
	#   
	#   @person = Person.find({:name => 'mike'}, :max_records => 50)[0]
	#   @person.update_attributes(:name => 'Michael', :title => "Senior Partner")
	#   @person.save
	# 
	#
	require 'active_support/core_ext/string/inflections'
	require 'rfm/database'
	require 'rfm/layout'
	require 'rfm/record'
	require 'rfm/utilities/factory'
	require 'delegate' 
  
  class Layout

  	class SubLayout < DelegateClass(Layout)
  		# Added by wbr to give config heirarchy: layout -> model -> sublayout
			include Config  	
  	
  		include Layout::LayoutModule
   		attr_accessor :model, :parent_layout

  		def initialize(master)
  			super(master)
  			self.parent_layout = master
  		end
  	end # SubLayout
  	
    attr_accessor :subs
  	
  	alias_method :main_init, :initialize
		def initialize(*args)
	    @subs ||= []
	    main_init(*args)
	  end
    
    def sublayout
    	if self.is_a?(Rfm::Layout)
    		sub = SubLayout.new(self); subs << sub; sub
    	else
    		self
    	end
    end
  	
    # Creates new class with layout name, subclassed from Rfm::Base, and links the new model to a SubLayout instance.
    def modelize
    	model_name = name.to_s.gsub(/\W/, '_').classify.gsub(/_/,'')
    	(return model_name.constantize) rescue nil
    	sub = sublayout
    	sub.instance_eval do
	    	model_class = eval("::" + model_name + "= Class.new(Rfm::Base)")
	    	model_class.class_exec(self) do |layout_obj|
	    		@layout = layout_obj
	    	end
	    	@model = model_class
	    	
	  		# Added by wbr to give config heirarchy: layout -> model -> sublayout
	  		model.config :parent=>'@layout.parent_layout'
	    	config :parent=>'model'
	    end
	    sub.model.to_s.constantize
    rescue StandardError, SyntaxError
    	nil
  	end
  	
  	def models
  		subs.collect{|s| s.model}
  	end

  end # Layout
  



        
  class Record
  	class << self
			def new(*args)
				#puts "Creating new record from RECORD. Layout: #{args[3].class} #{args[3].object_id}"
				args[3].model.new(*args)
			rescue
				#puts "RECORD failed to send 'new' to MODEL"
				super
				#allocate.send(:initialize, *args)
			end
    end # class << self
  end # class Record




  
  class Database
  	def_delegators :layouts, :modelize, :models
  end



  
  module Factory
    @models ||= []

  	class << self
  		attr_accessor :models
  		
	  	# Shortcut to Factory.db().layouts.modelize()
	  	# If first parameter is regex, it is used for modelize filter.
	  	# Otherwise, parameters are passed to Factory.database
	  	def modelize(*args)
	  		regx = args[0].is_a?(Regexp) ? args.shift : /.*/
	  		db(*args).layouts.modelize(regx)
	  	end
  	end # class << self
  	
  	class LayoutFactory
    	def modelize(filter = /.*/)
    		all.values.each{|lay| lay.modelize if lay.name.match(filter)}
    		models
    	end
    	
    	def models
	    	rslt = {}
    		each do |k,lay|
    			layout_models = lay.models
    			rslt[k] = layout_models if !layout_models.blank?
	    	end
	    	rslt
    	end
    	
    end # LayoutFactory
  end # Factory
	


	
  class Base <  Rfm::Record  #Hash
    extend Config
    config :parent => 'Rfm::Config'
    
    begin
    	require 'active_model'
      include ActiveModel::Validations
      include ActiveModel::Serialization
      extend ActiveModel::Callbacks
      include ActiveModel::Validations::Callbacks
      define_model_callbacks(:create, :update, :destroy)
    rescue LoadError, StandardError
    	def run_callbacks(*args)
    		yield
    	end
    end
    
		def initialize(record={}, resultset_obj=[], field_meta='', layout_obj=self.class.layout, portal=nil)
			if resultset_obj == [] and !record.respond_to?(:columns) #.has_key? 'field'
				@mods = Rfm::CaseInsensitiveHash.new
				@layout = layout_obj
				@resultset = Resultset.allocate
        # loop thru each layout field, creating hash keys with nil values
        layout_obj.field_names.each do |field|
          field_name = field.to_s
          self[field_name] = nil
        end
        self.update_attributes(record) unless record == {}
        self.merge!(@mods) unless @mods == {}
        @loaded = true
      else
      	super
      end
		end
		
    def to_partial_path(object = self) #@object)
    	return 'some/partial/path'
    	##### DISABLED HERE - ActiveModel Lint only needs a string #####
    	##### TODO: implement to_partial_path to return meaningful string.
      @partial_names[object.class.name] ||= begin
        object = object.to_model if object.respond_to?(:to_model)

        object.class.model_name.partial_path.dup.tap do |partial|
          path = @view.controller_path
          partial.insert(0, "#{File.dirname(path)}/") if partial.include?(?/) && path.include?(?/)
        end
      end
    end
		
		class << self
		
	    # Access layout functions from base model
	  	def_delegators :layout, :db, :server, :field_controls, :field_names, :value_lists, :total_count,
	  									:query, :all, :delete, :portal_meta, :portal_names, :database, :table, :count, :ignore_bad_data

			def inherited(model)
				(Rfm::Factory.models << model).uniq unless Rfm::Factory.models.include? model
				model.config :parent=>'Rfm::Base'
			end
		
			# Build a new record without saving
		  def new(*args)
		  	# Without this method, infinite recursion will happen from Record.new
		  	#puts "Creating new record from BASE"
		    rec = self.allocate
		    rec.send(:initialize, *args)
		    rec
		  end
		  
	    def config(*args)
	    	super(*args){|strings| @config.merge!(:layout=>strings[0]) if strings[0]}
	    end
		  		  			
			# Access/create the layout object associated with this model
	  	def layout
	  		return @layout if @layout
	  		cnf = get_config
	  		raise "Could not get :layout from get_config in Base.layout method" unless cnf[:layout] #return unless cnf[:layout]
	  		@layout = Rfm::Factory.layout(cnf).sublayout
	  		
	  		# Added by wbr to give config heirarchy: layout -> model -> sublayout
	  		config :parent=>'parent_layout'
	  		@layout.config :parent=>'model'
	  		
				@layout.model = self
				@layout
	  	end
	  	
	  	# Access the parent layout of this model
	  	def parent_layout
	  		layout.parent_layout
	  	end
		  			
			# Just like Layout#find, but searching by record_id will return a record, not a resultset.
	  	def find(find_criteria, options={})
	  		#puts "base.find-#{layout.object_id}"
	  	  r = layout.find(find_criteria, options)
	  	  if ![Hash,Array].include?(find_criteria.class) and r.size == 1
	  	    r[0]
		    else
		      r
	      end
	    rescue Rfm::Error::RecordMissingError
	      nil
	  	end

			# Layout#any, returns single record, not resultset
	  	def any(*args)
	  	  layout.any(*args)[0]
	  	end

			# New record, save, (with callbacks & validations if ActiveModel is loaded)
	  	def create(*args)
	  	  new(*args).send :create
	  	end
	  		  
	    # Using this method will skip callbacks. Use instance method +#update+ instead
		  def edit(*args)
		    layout.edit(*args)[0]
	    end
	    
		end # class << self


		
		

		
		# Is this a newly created record, not saved yet?					
  	def new_record?
  		return true if self.record_id.blank?
  	end

		# Reload record from database
		# TODO: handle error when record has been deleted
		def reload(force=false)
	    if (@mods.empty? or force) and record_id
	    	@mods.clear
	      self.replace self.class.find(self.record_id)
      end
    end
    
    # Mass update of record attributes, without saving.
    # TODO: return error or nil if input hash contains no recognizable keys.
    def update_attributes(new_attr)
      # creates new special hash
      input_hash = Rfm::CaseInsensitiveHash.new
      # populate new hash with input, coercing keys to strings
      new_attr.each{|k,v| input_hash.merge! k.to_s=>v}
      # loop thru each layout field, adding data to @mods
      self.class.field_controls.keys.each do |field| 
        field_name = field.to_s
        if input_hash.has_key?(field_name)
          @mods.merge! field_name=>(input_hash[field_name] || '')
        end
      end
      # loop thru each input key-value,
      # creating new attribute if key doesn't exist in model.
      input_hash.each do |k,v| 
        if !self.class.field_controls.keys.include?(k) and self.respond_to?(k)
          self.instance_variable_set("@#{k}", v)
        end
      end            
      self.merge!(@mods) unless @mods == {}
    end
    
    # Mass update of record attributes, with saving.
    def update_attributes!(new_attr)
      self.update_attributes(new_attr)
      self.save!
    end
    
    # Save record modifications to database (with callbacks & validations). If record cannot be saved will raise error.
    def save!
      #raise "Record Invalid" unless valid? rescue nil
      if @record_id
        self.update
      else
        self.create
      end
    end
    
	  # Same as save!, but will not raise error.
    def save
      save!
    rescue
      # (self.errors[:base] rescue []) << $!
      return nil
    end
	  
		# Just like Layout#save_if_not_modified, but with callbacks & validations.
    def save_if_not_modified
      update(@mod_id) if @mods.size > 0
    end    
    
    # Delete record from database, with callbacks & validations.
  	def destroy
  	  return unless record_id
  	  run_callbacks :destroy do
  	    self.class.delete(record_id)
  	    @destroyed = true
  	    @mods.clear
	    end
	    self.freeze
  	  #self
	  end
	  
	  def destroyed?
	  	@destroyed
	  end
	  
		# For ActiveModel compatibility
		def to_model
			self
		end
		
		def persisted?
			record_id ? true : false
		end
		
		def to_key
			record_id ? [record_id] : nil
		end
		
		def to_param
			record_id
		end
    
	
  protected # Base
  
  	def self.create_from_new(*args)
  	  layout.create(*args)[0]
  	end
  
    # shunt for callbacks when not using ActiveModel
    def callback_deadend (*args)
      yield  #(*args)
    end
    
    def create
      raise "Record not valid" if (defined?(ActiveModel::Validations) && !valid?)
      run_callbacks :create do
        return unless @mods.size > 0
  	    merge_rfm_result self.class.create_from_new(@mods)
  	  end
  	  self
  	end
  	
    def update(mod_id=nil)
      raise "Record not valid" if (defined?(ActiveModel::Validations) && !valid?)
      return false unless record_id 
  	  run_callbacks :update do
  	    return unless @mods.size > 0
  	    unless mod_id
  	      # regular save
  	      merge_rfm_result self.class.send :edit, record_id, @mods
	      else
	        # save_if_not_modified
	        merge_rfm_result self.class.send :edit, record_id, @mods, :modification_id=>mod_id
        end
  	  end
  	  self
  	end
  	
  	def merge_rfm_result(result_record)
      return unless @mods.size > 0
      @record_id ||= result_record.record_id
      self.merge! result_record
      @mods.clear
      self || {}
    end
    
  end # Base

end # Rfm



