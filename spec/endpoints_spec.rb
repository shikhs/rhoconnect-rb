require File.join(File.dirname(__FILE__), 'spec_helper')

describe Rhoconnect::EndpointHelpers do
  
  # Auth stub class
  class AuthTest; end
  class BrokenResource < ActiveRecord::Base
    include Rhoconnect::Resource
  end
  
  # Query stub class
  class Product < ActiveRecord::Base
    include Rhoconnect::Resource
    def self.rhoconnect_query(partition)
      [self.new]
    end
  end
  
  def setup_auth_test(success)
    AuthTest.stub!(:do_auth).and_return(success)
    AuthTest.should_receive(:do_auth).with(@creds)
    
    Rhoconnect.configure do |config|
      config.uri = "http://test.rhoconnect.com"
      config.token = "token"
      config.authenticate = lambda {|credentials|
        AuthTest.do_auth(credentials)
      }  
    end
  end
  
  before(:all) do
    @params = {'partition' => 'testuser', 'resource' => 'Product'}
    @creds = {'user' => 'john', 'pass' => 'secret'}
  end
  
  context "on Rails auth endpoint" do
    before(:each) do
      strio = mock("StringIO")
      strio.stub!(:read).and_return(JSON.generate(@creds))
      @env = mock("env")
      @env.stub!(:body).and_return(strio)
      @env.stub!(:content_type).and_return('application/json')
      Rack::Request.stub!(:new).and_return(@env)
    end
    
    it "should call configured authenticate block" do
      setup_auth_test(true)
      Rhoconnect::Authenticate.call(@env).should == [
        200, {'Content-Type' => 'text/plain'}, [""]
      ]
    end
    
    it "should call configured authenticate block with 401" do
      setup_auth_test(false)
      Rhoconnect::Authenticate.call(@env).should == [
        401, {'Content-Type' => 'text/plain'}, [""]
      ]
    end
    
    it "should return true if no authenticate block exists" do
      Rhoconnect.configure do |config|
        config.uri = "http://test.Rhoconnect.com"
        config.token = "token" 
      end
      Rhoconnect.configuration.authenticate.should be_nil
      Rhoconnect::Authenticate.call(@env).should == [
        200, {'Content-Type' => 'text/plain'}, [""]
      ]
    end
    
    it "should call authenticate block with empty params" do
      Rhoconnect::EndpointHelpers.authenticate('text/plain', '').should == [
        200, {"Content-Type"=>"text/plain"}, [""]
      ]
    end
  end
    
  context "on Create/Update/Delete/Query endpoints" do
    before(:each) do
      @strio = mock("StringIO")
      @env = mock("env")
      @env.stub!(:content_type).and_return('application/json')
    end
    
    it "should call query endpoint" do
      @strio.stub!(:read).and_return(
        {'partition' => 'testuser', 'resource' => 'Product'}.to_json
      )
      @env.stub!(:body).and_return(@strio)
      Rack::Request.stub!(:new).and_return(@env)
      code, content_type, body = Rhoconnect::Query.call(@env)
      code.should == 200
      content_type.should == { "Content-Type" => "application/json" }
      JSON.parse(body[0]).should == { '1' => Product.new.normalized_attributes }
    end
    
    it "should fail on missing Rhoconnect::Resource" do
      @strio.stub!(:read).and_return(
        {'partition' => 'testuser', 'resource' => 'Broken'}.to_json
      )
      @env.stub!(:body).and_return(@strio)
      Rack::Request.stub!(:new).and_return(@env)
      code, content_type, body = Rhoconnect::Query.call(@env)
      code.should == 404
      content_type.should == { "Content-Type" => "text/plain" }
      body[0].should == "Missing Rhoconnect::Resource Broken"
    end
    
    it "should fail on undefined rhoconnect_query method" do
      @strio.stub!(:read).and_return(
        {'partition' => 'testuser', 'resource' => 'BrokenResource'}.to_json
      )
      @env.stub!(:body).and_return(@strio)      
      Rack::Request.stub!(:new).and_return(@env)
      code, content_type, body = Rhoconnect::Query.call(@env)
      code.should == 404
      content_type.should == { "Content-Type" => "text/plain" }
      body[0].should == "error on method `rhoconnect_query` for BrokenResource: undefined method `rhoconnect_query' for BrokenResource:Class"
    end
    
    it "should fail on unknown exception" do
      @strio.stub!(:read).and_return(
        {'partition' => 'testuser', 'resource' => 'Product'}.to_json
      )
      @env.stub!(:body).and_return(@strio)      
      Rack::Request.stub!(:new).and_return(@env)
      Product.stub!(:rhoconnect_receive_create).and_return { raise "error in create" }
      code, content_type, body = Rhoconnect::Create.call(@env)
      code.should == 500
      content_type.should == { "Content-Type" => "text/plain" }
      body[0].should == "error in create"
    end
    
    it "should call create endpoint" do
      params = {
        'resource' => 'Product',
        'partition' => 'app',
        'attributes' => {
          'name' => 'iphone',
          'brand' => 'apple'
        }
      }
      @strio.stub!(:read).and_return(params.to_json)
      @env.stub!(:body).and_return(@strio)      
      Rack::Request.stub!(:new).and_return(@env)
      code, content_type, body = Rhoconnect::Create.call(@env)
      code.should == 200
      content_type.should == { "Content-Type" => "text/plain" }
      body.should == ['1']
    end
    
    it "should call update endpoint" do
      params = {
        'resource' => 'Product',
        'partition' => 'app',
        'attributes' => {
          'id' => '123',
          'name' => 'iphone',
          'brand' => 'apple'
        }
      }
      @strio.stub!(:read).and_return(params.to_json)
      @env.stub!(:body).and_return(@strio)      
      Rack::Request.stub!(:new).and_return(@env)
      code, content_type, body = Rhoconnect::Update.call(@env)
      code.should == 200
      content_type.should == { "Content-Type" => "text/plain" }
      body.should == ["123"]
    end
    
    it "should call delete endpoint" do
      params = {
        'resource' => 'Product',
        'partition' => 'app',
        'attributes' => {
          'id' => '123',
          'name' => 'iphone',
          'brand' => 'apple'
        }
      }
      @strio.stub!(:read).and_return(params.to_json)
      @env.stub!(:body).and_return(@strio)      
      Rack::Request.stub!(:new).and_return(@env)
      code, content_type, body = Rhoconnect::Delete.call(@env)
      code.should == 200
      content_type.should == { "Content-Type" => "text/plain" }
      body.should == ["123"]
    end
      
  end
  
  context "on Sinatra endpoints" do    
    class EndpointTest
      include Sinatra::RhoconnectHelpers
    end
  
    it "should register endpoints for authenticate and query" do
      strio = mock("StringIO")
      strio.stub!(:read).and_return(@creds.to_json)      
      req = mock("request")
      req.stub!(:body).and_return(strio)
      req.stub!(:env).and_return('CONTENT_TYPE' => 'application/json')
      Sinatra::RhoconnectEndpoints.stub!(:request).and_return(req)
      Sinatra::RhoconnectEndpoints.stub!(:params).and_return(@params)
      Rhoconnect::EndpointHelpers.stub!(:query)
      app = mock("app")
      app.stub!(:post).and_yield
      app.should_receive(:post).exactly(5).times
      app.should_receive(:include).with(Sinatra::RhoconnectHelpers)
      Sinatra::RhoconnectEndpoints.should_receive(:call_helper).exactly(5).times
      Sinatra::RhoconnectEndpoints.registered(app)
    end
    
    it "should call helper for authenticate" do
      app = EndpointTest.new
      app.should_receive(:status).with(200)
      app.should_receive(:content_type).with('text/plain')
      app.call_helper(
        :authenticate, 'application/json', @creds.to_json
      ).should == ""
    end
    
    it "should call helper for query" do
      app = EndpointTest.new
      app.should_receive(:status).with(200)
      app.should_receive(:content_type).with('application/json')
      result = app.call_helper(
        :query, 'application/json', @params.to_json
      )
      JSON.parse(result).should == { '1' => Product.new.normalized_attributes }
    end
  end
end