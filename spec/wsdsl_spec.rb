require File.expand_path("spec_helper", File.dirname(__FILE__))

describe WSDSL do
  
  before :all do
    @service = WSList.all.find{|s| s.url == 'services/test.xml'}
    @service.should_not be_nil
  end
  
  it "should have an url" do
    # dummy test since that's how we found the service, but oh well
    @service.url.should be == 'services/test.xml'
  end
  
  it "should have some http verbs defined" do
    @service.verb.should be == :get
  end
  
  it "should have supported formats defined" do
    @service.formats.should be == [:xml, :json]
  end
  
  it "should have params info" do
    @service.params.should be_an_instance_of(WSDSL::Params)
  end

  it "should have direct access to the required params" do
    @service.required_rules.should be == @service.params.list_required
  end
  
  it "should have direct access to the optional params" do
    @service.optional_rules.should be == @service.params.list_optional
  end
  
  it "should have direct access to the nested params" do
    @service.nested_params.should be == @service.params.namespaced_params
  end
  
  it "should set the controller accordingly" do
    @service.controller_name.should_not be_nil
    @service.controller_name.should be == 'ServicesController'
    service = WSDSL.new("preferences.xml")
    service.name.should be == 'preferences'
    ExtlibCopy.classify('preferences').should be == 'Preferences'
    service.controller_name.should be == 'PreferencesController'
  end
  
  it "should set the action accordingly" do
    @service.action.should_not be_nil
    @service.action.should be == 'test' 
  end
  
  it "should support restful routes based on the HTTP verb" do
    service = WSList.all.find{|s| s.url == "services.xml"}
    service.should_not be_nil
    service.http_verb.should be == :put
    service.action.should_not be_nil
    service.controller_name.should be == 'ServicesController'
    service.action.should be == 'update'
  end

  it "should have a default action" do
   service = WSDSL.new('spec_test.xml')
   service.action.should be == 'list'
  end

  it "should route to show when an id is the last passed param" do
    service = WSDSL.new("players/:id.xml")
    service.action.should be == 'show'
  end

  it "should support some extra attributes" do
    service = WSDSL.new("players/:id.xml")
    service.extra[:custom_name] = 'fooBar'
    service.extra[:custom_name].should be == 'fooBar'
  end

  it "should respect the global controller pluralization flag" do
    WSDSL.use_pluralized_controllers = true
    service = WSDSL.new("player/:id.xml")
    service.controller_name.should be == "PlayersController"
    service = WSDSL.new("players/:id.xml")
    service.controller_name.should be == "PlayersController"
    WSDSL.use_pluralized_controllers = false
    service = WSDSL.new("player/:id.xml")
    service.controller_name.should be == "PlayerController"
  end


  it "should let overwrite the controller name and action after initialization" do
    describe_service "players/:id.xml" do |service|
      service.controller_name "CustomController"
      service.action :foo
    end
    service = WSList.all.find{|s| s.url == "players/:id.xml"}
    service.controller_name.should be == "CustomController"
    service.action.should be == :foo
  end

  describe WSDSL::Params do
    
    before(:all) do
      @sparams = @service.params
    end
    
    it "should have the possibility to have a space name" do
      @sparams.should respond_to(:space_name)
      service_params = WSDSL::Params.new(:space_name => 'spec_test')
      service_params.space_name.should be == 'spec_test'
    end
    
    it "should have a list of required param rules" do
      @sparams.list_required.should be_an_instance_of(Array)
      @sparams.list_required.length.should be == 1
    end

    it "should have a list of optional param rules" do
      @sparams.list_optional.should be_an_instance_of(Array)
      @sparams.list_optional.length.should be == 4
    end
    
    it "should have a list of namespaced param rules" do
      @sparams.namespaced_params.should be_an_instance_of(Array)
      @sparams.namespaced_params.length.should be == 1
      @sparams.namespaced_params.first.space_name.should be == :user
    end
    
    describe WSDSL::Params::Rule do
      before :all do
        @rule = @sparams.list_required.first
        @rule.should_not be_nil
      end
      
      it "should have a name" do
        @rule.name.should be == :framework
      end
      
      it "should have options" do
        @rule.options[:type].should be == :string
        @rule.options[:in].should be ==  WSDSLSpecOptions
        @rule.options[:null].should be_false
      end
    end
    
  end
  
  it "should have some documentation" do
    @service.doc.should be_an_instance_of(WSDSL::Documentation)
  end
  
  describe WSDSL::Documentation do
    before(:all) do
      @doc = @service.doc
      @doc.should_not be_nil
    end
    
    it "should have an overall description" do
      @doc.desc.strip.should be == "This is a test service used to test the framework."
    end
    
    it "should have a list of params doc" do
      @doc.params_doc.should be_an_instance_of(Hash)
      @doc.params_doc.keys.sort.should be == [:framework, :version]
      @doc.params_doc[:framework].should be == "The test framework used, could be one of the two following: #{WSDSLSpecOptions.join(", ")}."
    end
    
    it "should allow to define namespaced params doc" do
      service = WSList.all.find{|s| s.url == "services.xml"}
      service.documentation do |doc|
        doc.namespace :preference do |ns|
          ns.param :id, "Ze id."
        end
      end
      service.doc.namespaced_params.should_not be_empty
      ns = service.doc.namespaced_params.find{|nsp| nsp.name == :preference}
      ns.should_not be_nil
      ns.params[:id].should be == "Ze id."
    end
    
    it "should have an optional list of examples" do
      @doc.examples.should be_an_instance_of(Array)
      @doc.examples.first.should be == <<-DOC
The most common way to use this service looks like that:
    http://example.com/services/test.xml?framework=rspec&version=2.0.0
      DOC
    end
    
    it "should have the service response documented" do
      @doc.response.should_not be_nil
    end
    
    it "should have documentation for the response elements via the response itself" do
      @service.response.elements.first.should_not be_nil
      @service.response.elements.first.doc.should_not be_nil
      @service.response.elements.first.doc.name.should be == "player_creation_ratings"
    end

    it "should have documentation for a response element attribute" do
      @service.response.elements.first.doc.attributes.should_not be_empty
      @service.response.elements.first.doc.attributes[:id].should be == "id doc"
    end
    
    it "should have documentation for a response element array" do
      element = @service.response.elements.first
      element.arrays.should_not be_empty
      element.arrays.first.name.should be == "player_creation_rating"
      element.arrays.first.obj_type.should be == "PlayerCreationRating"
      element.arrays.first.attributes.should_not be_empty
    end
    
    it "should have documentation for the attributes of an response element array" do
      element = @service.response.elements.first
      array = element.arrays.first
      attribute = array.attributes.find{|att| att.name == :comments }
      attribute.should_not be_nil
      attribute.name.should be == :comments # just in case we change the way to find the attribute
      attribute.doc.should be == "comments doc"
    end

  end

end
