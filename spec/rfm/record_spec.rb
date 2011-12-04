require 'rfm/record'
describe Rfm::Record do
  before(:each) do
    @record = Rfm::Record.allocate
    @layout = mock(Rfm::Layout)
  end
  
  describe "#[]=" do
    before(:each) do
      @record.instance_variable_set(:@mods, {})
      @record.instance_variable_set(:@loaded, false)
      @record['tester'] = 'red'
    end
    
    it "creates a new hash key => value upon instantiation of record" do
      @record.has_key?('tester').should be_true
      @record['tester'].should eql('red')
    end
    
    it "creates a new hash key => value in @mods when modifying an existing record key" do
      @record.instance_variable_set(:@loaded, true)
      @record['tester'] = 'green'
      
      @record.instance_variable_get(:@mods).has_key?('tester').should be_true
      @record.instance_variable_get(:@mods)['tester'].should eql('green')
    end
    
    it "modifies the hash key => value in self whether key is string or symbol" do
      @record.instance_variable_set(:@loaded, true)
      @record[:tester] = 'green'
      
      @record.has_key?(:tester).should be_false
      @record['tester'].should eql('green')
    end
    
    it "returns nil if hash key is '' " do
      @record['tester'] = ''
      @record['tester'].should eql(nil)
    end
    
    it "returns nil if hash key is nil " do
      @record['tester'] = nil
      @record['tester'].should eql(nil)
    end
    
    it "raises an Rfm::ParameterError if a value is set on a key that does not exist" do
      @record.instance_variable_set(:@loaded, true)

      ex = rescue_from { @record['tester2'] = 'error' }
      ex.class.should eql(Rfm::ParameterError)
      ex.message.should eql('You attempted to modify a field that does not exist in the current Filemaker layout.')
    end
    
    it "raises an NoMethodError if a key is used that does not exist" do
      @record.instance_variable_set(:@loaded, true)
      @record.instance_variable_set(:@layout, 'dummy') # will allow this test to pass

      ex = rescue_from { @record['tester2'] }
      ex.class.should eql(NoMethodError)
      ex.message.should eql('tester2 does not exists as a field in the current Filemaker layout.')
    end
    
  end
  
  describe "#respond_to?" do
    it "returns true if key is in hash" do
      @record['red'] = 'stop'
      
      @record.respond_to?(:red).should be_true
    end
    
    it "returns false if key is not in hash" do
      @record.respond_to?(:red).should be_false
    end
  end
  
  describe "#method_missing" do
    before(:each) do
      @record.instance_variable_set(:@mods, {})
      @record['name'] = 'red'
    end
    
    describe "getter" do
      it "will match a method to key in the hash if there is one" do
        @record.name.should eql('red')
      end

      it "will raise NoMethodError if no key present that matches value" do
        ex = rescue_from { @record.namee }
        ex.class.should eql(NoMethodError)
        ex.message.should match(/undefined method `namee'/)
      end
    end
    
    describe "setter" do
      it "acts as a setter if the key exists in the hash" do
      	@record.instance_variable_set(:@loaded, true)
        @record.name = 'blue'

        @record.instance_variable_get(:@mods).has_key?('name').should be_true
        @record.instance_variable_get(:@mods)['name'].should eql('blue')
      end
      
      it "will raise NoMethodError if no key present that matches value" do
        ex = rescue_from { @record.namee = 'red' }
        ex.class.should eql(NoMethodError)
        ex.message.should match(/undefined method `namee='/)
      end
    end

  end
  
  describe "#save" do
	  before(:each) do
	  	@record['name'] = 'red'
  		@record.instance_variable_set(:@record_id, 1)
	  	@record.instance_variable_set(:@loaded, true)
	  	@record.instance_variable_set(:@layout, @layout)
	  	
	  	@mods = @record.instance_variable_set(:@mods, {})	
	  	@layout.stub!(:edit).with(1, @mods).and_return([@mods])
    end
    
    it "passes mods to Layout::edit" do
    	@record.name = 'green'
    	@layout.should_receive(:edit).with(1, {'name'=>'green'})
    	@record.save
    end
    
    it "returns empty hash" do
	  		@record.name = 'green'
  			@record.save.should eql({})
    end
    
  	context "when modified" do
  		it "merges new hash from saved data" do
	  		@mods['name'] = 'green'
  			@record.save
  			@record['name'].should eql('green')
  		end
  	end
  	
  	context "when not modified" do
  		it "leaves self untouched" do
  			original = @record.dup
  			@record.save
  			@record.should eql(original)
  		end
  	end
  	
  end #save
  
  describe "#save_if_not_modified" do
  	before(:each) do
  		@record['name'] = 'red'
			@record.instance_variable_set(:@record_id, 1)
			@record.instance_variable_set(:@loaded, true)
			@record.instance_variable_set :@mod_id, 5
			@record.instance_variable_set(:@layout, @layout)
			@mods = @record.instance_variable_set(:@mods, {})	
			@layout.stub!(:edit).and_return{[@mods]}
		end
		
		context "when local record not modified" do
			it "leaves self untouched and returns {}" do
				original = @record.dup
				@record.save_if_not_modified.should eql({})
				@record.should eql(original)
			end
		end
		
		context "when local record modified" do
			it "passes @mods and @mod_id to layout" do
	    	@record.name = 'green'
	    	@layout.should_receive(:edit).with(1, {'name'=>'green'}, {:modification_id => 5})
	    	@record.save_if_not_modified
 			end
 			
 			it "merges returned hash from Layout#edit" do
 				@record.name = 'blue'
 				@mods['name'] = 'green'
 				@record.save_if_not_modified
 				@record['name'].should eql('green')
 			end
 			
 			it "clears @mods" do
 				@record.name = 'green'
 				@record.save_if_not_modified
 				@record.instance_variable_get(:@mods).should eql({})
 			end
 			
 			it "returns {}" do
 				@record.name = 'green'
 				@record.save_if_not_modified.should eql({})
 			end
		end
		
  end #save_if_not_modified
  
  
end #Rfm::Record