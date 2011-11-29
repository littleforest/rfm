module Rfm
module Metadata

  # The ValueListItem object represents a item in a Filemaker value list. 
  #
  # =Attributes
  #
  # * *value* the value list item value
  #
  # * *display* is the value list item display string
  # * * it could be the same as value, or it could be the "second field"  # * * :scrollable - an editable field with scroll bar
  # * * if that option is checked in Filemaker
  #
  # * *value_list_name* is the name of the parent value list, if any
  class ValueListItem < String
    def initialize(value, display, value_list_name)
    	value            = value.to_s
    	display          = display.to_s
      @value_list_name = value_list_name
      @value					 = value
      @display				 = display
      self.replace value
    end
    
    attr_reader :value, :display, :value_list_name
  
  end
end
end