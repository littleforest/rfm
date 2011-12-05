require 'rfm/layout'
#require 'yaml'

describe Rfm::Layout do
  let(:server)   {(Rfm::Server).allocate}
  let(:database) {(Rfm::Database).allocate}
  let(:data)     {File.read("spec/data/resultset.xml").to_s}
  let(:name)     {'test'}
  subject        {Rfm::Layout.new(name, database)}
  before(:each) do
		server.stub!(:connect).and_return(data)
		server.stub!(:state).and_return({})
		database.stub!(:server).and_return(server)
		data.stub!(:body).and_return(data)
  end

	describe "#initialze" do
		it "should load instance variables" do
			subject.instance_variable_get(:@name).should == name
			subject.instance_variable_get(:@db).should == database
			subject.instance_variable_get(:@loaded).should == false
			subject.instance_variable_get(:@field_controls).class.should == Rfm::CaseInsensitiveHash
			subject.instance_variable_get(:@value_lists).class.should == Rfm::CaseInsensitiveHash
		end
	end # initialize
	
	describe "#get_records" do
		it "calls @db.server.connect(@db.account_name, @db.password, action, params.merge(extra_params), options)"
		it "calls Rfm::Resultset.new(@db.server, xml_response, self, include_portals)"
		it "returns instance of Resultset"
	end
	
	describe "Functional Tests" do
		it "#load_records returns an instance of Rfm::Resultset" do
			subject.send(:get_records, '-all', {}, {}).class.should == Rfm::Resultset
		end
		it "#any returns resultset containing instance of Rfm::Record" do
			subject.send(:any)[0].class.should == Rfm::Record
		end
	end
	
	describe "#load" do
		it "sets @field_controls to something" do
			#subject.field_controls.should_not == nil
		end
	end

end # Rfm::Resultset