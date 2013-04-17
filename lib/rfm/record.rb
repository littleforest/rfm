module Rfm
  # The Record object represents a single FileMaker record. You typically get them from ResultSet objects.
  # For example, you might use a Layout object to find some records:
  #
  #   results = myLayout.find({"First Name" => "Bill"})
  #
  # The +results+ variable in this example now contains a ResultSet object. ResultSets are really just arrays of
  # Record objects (with a little extra added in). So you can get a record object just like you would access any 
  # typical array element:
  #
  #   first_record = results[0]
  #
  # You can find out how many record were returned:
  #
  #   record_count = results.size
  #
  # And you can of course iterate:
  # 
  #   results.each (|record|
  #     // you can work with the record here
  #   )
  #
  # =Accessing Field Data
  #
  # You can access field data in the Record object in two ways. Typically, you simply treat Record like a hash
  # (because it _is_ a hash...I love OOP). Keys are field names:
  # 
  #   first = myRecord["First Name"]
  #   last = myRecord["Last Name"]
  #
  # If your field naming conventions mean that your field names are also valid Ruby symbol named (ie: they contain only
  # letters, numbers, and underscores) then you can treat them like attributes of the record. For example, if your fields
  # are called "first_name" and "last_name" you can do this:
  #
  #   first = myRecord.first_name
  #   last = myRecord.last_name
  #
  # Note: This shortcut will fail (in a rather mysterious way) if your field name happens to match any real attribute
  # name of a Record object. For instance, you may have a field called "server". If you try this:
  # 
  #   server_name = myRecord.server
  # 
  # you'll actually set +server_name+ to the Rfm::Server object this Record came from. This won't fail until you try
  # to treat it as a String somewhere else in your code. It is also possible a future version of Rfm will include
  # new attributes on the Record class which may clash with your field names. This will cause perfectly valid code
  # today to fail later when you upgrade. If you can't stomach this kind of insanity, stick with the hash-like
  # method of field access, which has none of these limitations. Also note that the +myRecord[]+ method is probably
  # somewhat faster since it doesn't go through +method_missing+.
  #
  # =Accessing Repeating Fields
  #
  # If you have a repeating field, RFM simply returns an array:
  #
  #   val1 = myRecord["Price"][0]
  #   val2 = myRecord["Price"][1]
  #
  # In the above example, the Price field is a repeating field. The code puts the first repetition in a variable called 
  # +val1+ and the second in a variable called +val2+.
  #
  # It is not currently possible to create or edit a record's repeating fields beyond the first repitition, using Rfm.
  #
  # =Accessing Portals
  #
  # If the ResultSet includes portals (because the layout it comes from has portals on it) you can access them
  # using the Record::portals attribute. It is a hash with table occurrence names for keys, and arrays of Record
  # objects for values. In other words, you can do this:
  #
  #   myRecord.portals["Orders"].each {|record|
  #     puts record["Order Number"]
  #   }
  #
  # This code iterates through the rows of the _Orders_ portal.
  #
  #	As a convenience, you can call a specific portal as a method on your record, if the table occurrence name does
  # not have any characters that are prohibited in ruby method names, just as you can call a field with a method:
	# 	
	#   myRecord.orders.each {|portal_row|
	#   	puts portal_row["Order Number"]
	#   }
	#   
  # =Field Types and Ruby Types
  #
  # RFM automatically converts data from FileMaker into a Ruby object with the most reasonable type possible. The 
  # type are mapped thusly:
  #
  # * *Text* fields are converted to Ruby String objects
  # 
  # * *Number* fields are converted to Ruby BigDecimal objects (the basic Ruby numeric types have
  #   much less precision and range than FileMaker number fields)
  #
  # * *Date* fields are converted to Ruby Date objects
  #
  # * *Time* fields are converted to Ruby DateTime objects (you can ignore the date component)
  #
  # * *Timestamp* fields are converted to Ruby DateTime objects
  #
  # * *Container* fields are converted to Ruby URI objects
  #
  # =Attributes
  #
  # In addition to +portals+, the Record object has these useful attributes:
  #
  # * *record_id* is FileMaker's internal identifier for this record (_not_ any ID field you might have
  #   in your table); you need a +record_id+ to edit or delete a record
  #
  # * *mod_id* is the modification identifier for the record; whenever a record is modified, its +mod_id+
  #   changes so you can tell if the Record object you're looking at is up-to-date as compared to another
  #   copy of the same record
  class Record < Rfm::CaseInsensitiveHash
    
    attr_accessor :layout, :resultset
    attr_reader :record_id, :mod_id, :portals
    def_delegators :resultset, :field_meta, :portal_names
    def_delegators :layout, :db, :database, :server

    def initialize(record, resultset_obj, field_meta, layout_obj, portal=nil)
    
      @layout        = layout_obj
      @resultset     = resultset_obj
      @record_id     = record.record_id rescue nil
      @mod_id        = record.mod_id rescue nil
      @mods          = {}
      @portals     ||= Rfm::CaseInsensitiveHash.new

      relatedsets = !portal && resultset_obj.instance_variable_get(:@include_portals) ? record.portals : []
      
      record.columns.each do |field|
      	next unless field
        field_name = @layout.field_mapping[field.name] || field.name rescue field.name
        field_name.gsub!(Regexp.new(portal + '::'), '') if portal
        datum = []
        data = field.data #['data']; data = data.is_a?(Hash) ? [data] : data
        data.each do |x|
        	next unless field_meta[field_name]
        	begin
	          datum.push(field_meta[field_name].coerce(x, resultset_obj)) #(x['__content__'], resultset_obj))
        	rescue StandardError => error
        		self.errors.add(field_name, error) if self.respond_to? :errors
        		raise error unless @layout.ignore_bad_data
        	end
        end if data
      
        if datum.length == 1
          rfm_super[field_name] = datum[0]
        elsif datum.length == 0
          rfm_super[field_name] = nil
        else
          rfm_super[field_name] = datum
        end
      end
      
      unless relatedsets.empty?
        relatedsets.each do |relatedset|
        	next if relatedset.blank?
          tablename, records = relatedset.table, []
      
          relatedset.records.each do |record|
          	next unless record
            records << self.class.new(record, resultset_obj, resultset_obj.portal_meta[tablename], layout_obj, tablename)
          end
      
          @portals[tablename] = records
        end
      end
      
      @loaded = true
    end

    def self.build_records(records, resultset_obj, field_meta, layout_obj, portal=nil)
      records.each do |record|
        resultset_obj << self.new(record, resultset_obj, field_meta, layout_obj, portal)
      end
    end

    # Saves local changes to the Record object back to Filemaker. For example:
    #
    #   myLayout.find({"First Name" => "Bill"}).each(|record|
    #     record["First Name"] = "Steve"
    #     record.save
    #   )
    #
    # This code finds every record with _Bill_ in the First Name field, then changes the first name to 
    # Steve.
    #
    # Note: This method is smart enough to not bother saving if nothing has changed. So there's no need
    # to optimize on your end. Just save, and if you've changed the record it will be saved. If not, no
    # server hit is incurred.
    def save
      self.merge!(layout.edit(self.record_id, @mods)[0]) if @mods.size > 0
      @mods.clear
    end

    # Like Record::save, except it fails (and raises an error) if the underlying record in FileMaker was
    # modified after the record was fetched but before it was saved. In other words, prevents you from
    # accidentally overwriting changes someone else made to the record.
    def save_if_not_modified
      self.merge!(layout.edit(@record_id, @mods, {:modification_id => @mod_id})[0]) if @mods.size > 0
      @mods.clear
    end
    
    # Gets the value of a field from the record. For example:
    #
    #   first = myRecord["First Name"]
    #   last = myRecord["Last Name"]
    #
    # This sample puts the first and last name from the record into Ruby variables.
    #
    # You can also update a field:
    #
    #   myRecord["First Name"] = "Sophia"
    #
    # When you do, the change is noted, but *the data is not updated in FileMaker*. You must call
    # Record::save or Record::save_if_not_modified to actually save the data.
  	def [](key)
  		return fetch(key.to_s.downcase)
  	rescue IndexError
    	raise Rfm::ParameterError, "#{key} does not exists as a field in the current Filemaker layout." unless key.to_s == '' #unless (!layout or self.key?(key_string))
  	end

    def respond_to?(symbol, include_private = false)
      return true if self.include?(symbol.to_s)
      super
    end
    
    def []=(key, val)
      key_string = key.to_s.downcase
      return super unless @loaded # is this needed?
      raise Rfm::ParameterError, "You attempted to modify a field (#{key_string}) that does not exist in the current Filemaker layout." unless self.key?(key_string)
      # @mods[key_string] = val
      # TODO: This needs cleaning up.
      # TODO: can we get field_type from record instead?
			@mods[key_string] = if [Date, Time, DateTime].member?(val.class)
				field_type = layout.field_meta[key_string.to_sym].result
				case field_type
					when 'time'; val.strftime(layout.time_format)
					when 'date'; val.strftime(layout.date_format)
					when 'timestamp'; val.strftime(layout.timestamp_format)
				else val
				end
			else val
			end
      super(key, val)
    end
		#
		# 		alias_method :old_setter, '[]='
		# 		def []=(key,val)
		# 			old_setter(key,val)
		# 			return val unless [Date, Time, DateTime].member? val.class
		# 			field_type = layout.field_meta[key.to_sym].result
		# 			@mods[key] = case field_type
		# 				when 'time'; val.strftime(layout.time_format)
		# 				when 'date'; val.strftime(layout.date_format)
		# 				when 'timestamp'; val.strftime(layout.timestamp_format)
		# 				else val
		# 			end
		# 		end  
		  
	  def field_names
    	resultset.field_names rescue layout.field_names
    end


  private

  	def method_missing (symbol, *attrs, &block)
  	  method = symbol.to_s
  	  return self[method] if self.key?(method)
  	  return @portals[method] if @portals and @portals.key?(method)

  	  if method =~ /(=)$/
  	    return self[$`] = attrs.first if self.key?($`)
  	  end
  	  super
		end
  	
  end # Record
end # Rfm