require_relative "spec_helper"

describe ParamsVerification do

  before :all do
    @service = WSList.all.find{|s| s.url == 'services/test.xml'}
    @service.should_not be_nil
  end

  before do
    @valid_params = {'framework' => 'RSpec', 'version' => '1.02', 'user' => {'id' => '123', 'groups' => 'manager,developer', 'skills' => 'java,ruby'}}
  end

  it "should validate valid params" do
    params = @valid_params.dup
    lambda{ ParamsVerification.validate!(params, @service.defined_params) }.should_not raise_exception
  end

  it "should return the params" do
    params = @valid_params.dup
    returned_params = ParamsVerification.validate!(params, @service.defined_params)
    returned_params.should be_an_instance_of(Hash)
    returned_params.keys.size.should >= 3
  end

  it "should return array in the params" do
    params = @valid_params
    returned_params = ParamsVerification.validate!(params, @service.defined_params)
    returned_params[:user][:groups].should == @valid_params['user']['groups'].split(",")
    returned_params[:user][:skills].should == @valid_params['user']['skills'].split(",")
  end

  it "should not duplicate params in the root level" do
    params = @valid_params
    returned_params = ParamsVerification.validate!(params, @service.defined_params)
    returned_params[:groups].should be_nil
    returned_params[:skills].should be_nil
  end

  it "should raise exception when values of required param are not in the allowed list" do
    params = @valid_params
    params['user']['groups'] = 'admin,root,manager'
    lambda { ParamsVerification.validate!(params, @service.defined_params) }.
      should raise_error(ParamsVerification::InvalidParamValue)
  end

  it "should raise exception when values of opitonal param are not in the allowed list" do
    params = @valid_params
    params['user']['skills'] = 'ruby,java,php'
    lambda { ParamsVerification.validate!(params, @service.defined_params) }.
      should raise_error(ParamsVerification::InvalidParamValue)
  end

  it "should set the default value for an optional param" do
    params = @valid_params
    params[:timestamp].should be_nil
    returned_params = ParamsVerification.validate!(params, @service.defined_params)
    returned_params[:timestamp].should_not be_nil
  end

  it "should set the default value for a namespace optional param" do
    params = {'framework' => 'RSpec', 'version' => '1.02', 'user' => {'id' => '123', 'groups' => 'admin'}}
    params[:user].should be_nil
    returned_params = ParamsVerification.validate!(params, @service.defined_params)
    returned_params[:user][:mailing_list].should be_true
  end

  it "should raise an exception when a required param is missing" do
    params = @valid_params.dup
    params.delete('framework')
    lambda{ ParamsVerification.validate!(params, @service.defined_params) }.should raise_exception(ParamsVerification::MissingParam)
  end

  it "should cast a comma delimited string into an array when param marked as an array" do
    service = WSList.all.find{|s| s.url == "services/array_param.xml"}
    service.should_not be_nil
    params = {'seq' => "a,b,c,d,e,g"}
    validated = ParamsVerification.validate!(params, service.defined_params)
    validated[:seq].should == %W{a b c d e g}
  end

  it "should not raise an exception if a req array param doesn't contain a comma" do
    service = WSList.all.find{|s| s.url == "services/array_param.xml"}
    params = {'seq' => "a b c d e g"}
    lambda{ ParamsVerification.validate!(params, service.defined_params) }.should_not raise_exception(ParamsVerification::InvalidParamType)
  end

  it "should raise an exception when a param is of the wrong type" do
    params = @valid_params.dup
    params['user']['id'] = 'abc'
    lambda{ ParamsVerification.validate!(params, @service.defined_params) }.should raise_exception(ParamsVerification::InvalidParamType)
  end

  it "should raise an exception when a param is under the minvalue" do
    params = @valid_params.dup
    params['num'] = 1
    lambda{ ParamsVerification.validate!(params, @service.defined_params) }.should raise_exception(ParamsVerification::InvalidParamValue)
  end

  it "should raise an exception when a param isn't in the param option list" do
    params = @valid_params.dup
    params['alpha'] = 'z'
    lambda{ ParamsVerification.validate!(params, @service.defined_params) }.should raise_exception(ParamsVerification::InvalidParamValue)
  end

  it "should raise an exception when a nested optional param isn't in the param option list" do
    params = @valid_params.dup
    params['user']['sex'] = 'large'
    lambda{ ParamsVerification.validate!(params, @service.defined_params) }.should raise_exception(ParamsVerification::InvalidParamValue)
    # other service
    params = {'preference' => {'region_code' => 'us', 'language_code' => 'de'}}
    service = WSList.all.find{|s| s.url == 'preferences.xml'}
    service.should_not be_nil
    lambda{ ParamsVerification.validate!(params, service.defined_params) }.should raise_exception(ParamsVerification::InvalidParamValue)
  end

  it "should validate that no params are passed when accept_no_params! is set on a service" do
    service = WSList.all.find{|s| s.url == "services/test_no_params.xml"}
    service.should_not be_nil
    params = @valid_params.dup
    lambda{ ParamsVerification.validate!(params, service.defined_params) }.should raise_exception
  end

end
