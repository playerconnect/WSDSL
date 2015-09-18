class WSDSL
  # Response DSL class
  # @api public
  class Response

    # The list of all the elements inside the response
    #
    # @return [Array<WSDSL::Response::Element>]
    # @api public
    attr_reader :elements

    def initialize
      @elements = []
    end

    # Defines a new element and yields the content of an optional block
    # Each new element is then stored in the elements array.
    #
    # @param [Hash] opts Options used to define the element
    # @option opts [String, Symbol] :name The element name
    # @option opts [String, Symbol] :type The optional type
    #
    # @yield [WSDSL::Response::Element] the newly created element
    # @example create an element called 'my_stats'.
    #   service.response do |response|
    #    response.element(:name => "my_stats", :type => 'Leaderboard')
    #   end
    #
    # @return [Array<WSDSL::Response::Element>]
    # @api public
    def element(opts={})
      el = Element.new(opts)
      yield(el) if block_given?
      @elements << el
    end

    # Returns a response element object based on its name
    # @param [String, Symbol] The element name we want to match
    #
    # @return [WSDSL::Response::Element]
    # @api public
    def element_named(name)
      @elements.find{|e| e.name.to_s == name.to_s}
    end

    # The Response element class describing each element of a service response.
    # Instances are usually not instiated directly but via the Response#element accessor.
    #
    # @see WSDSL::Response#element
    # @api public
    class Element

      # @return [String, #to_s] The name of the element
      # @api public
      attr_reader :name

      # @api public
      attr_reader :required

      # @api public
      attr_reader :type

      # @api public
      attr_reader :opts

      # @return [Array<WSDSL::Response::Element::Attribute>] An array of attributes
      # @api public
      attr_reader :attributes

      # @return [Array] An array of vectors/arrays
      # @api public
      attr_reader :vectors

      # @return [WSDSL::Documentation::ElementDoc] Response element documentation
      # @api public
      attr_reader :doc

      # @return [NilClass, Array<WSDSL::Response::Element>] The optional nested elements
      attr_reader :elements

      # param [String, Symbol] name The name of the element
      # param [String, Symbol] type The optional type of the element
      # @api public
      def initialize(opts={})
        opts[:type] ||= nil
        opts[:required] = nil if !opts.has_key?(:required)

        # sets a documentation placeholder since the response doc is defined at the same time
        # the response is defined.
        @name       = opts.delete(:name) if(opts.has_key?(:name))
        @doc        = Documentation::ElementDoc.new(@name)
        @type       = opts.delete(:type) if(opts.has_key?(:type))
        @required   = opts.has_key?(:required) ? opts[:required] : true
        @attributes = []
        @vectors    = []
        @opts       = opts
        # we don't need to initialize the nested elements, by default they should be nil
      end

      # sets a new attribute and returns the entire list of attributes
      #
      # @param [Hash] opts An element's attribute options
      # @option opts [String, Symbol] attribute_name The name of the attribute, the value being the type
      # @option opts [String, Symbol] :doc The attribute documentation
      # @option opts [String, Symbol] :mock An optional mock value used by service related tools
      # 
      # @example Creation of a response attribute called 'best_lap_time'
      #   service.response do |response|
      #    response.element(:name => "my_stats", :type => 'Leaderboard') do |e|
      #      e.attribute "best_lap_time"       => :float,    :doc => "Best lap time in seconds."
      #    end
      #   end
      #
      # @return [Array<WSDSL::Response::Attribute>]
      # @api public
      def attribute(opts)
        raise ArgumentError unless opts.is_a?(Hash)
        # extract the documentation part and add it where it belongs
        new_attribute = Attribute.new(opts)
        @attributes << new_attribute
        # document the attribute if description available
        # we might want to have a placeholder message when a response attribute isn't defined
        if opts.has_key?(:doc)
          @doc.attribute(new_attribute.name, opts[:doc])
        end
        @attributes
      end

      # Defines an array aka vector of elements.
      #
      # @param [Hash] opts A hash representing the array information, usually a name and a type.
      # @option opts [String, Symbol] :name The name of the defined array
      # @option opts [String, Symbol] :type The class name of the element inside the array
      #
      # @param [Proc] &block
      #   A block to execute against the newly created array.
      # 
      # @example Defining an element array called 'player_creation_rating'
      #   element.array :name => 'player_creation_rating', :type => 'PlayerCreationRating' do |a|
      #     a.attribute :comments  => :string
      #     a.attribute :player_id => :integer
      #     a.attribute :rating    => :integer
      #     a.attribute :username  => :string
      #   end
      # @yield [Vector] the newly created array/vector instance
      # @see Vector#initialize
      # 
      # @return [Array<WSDSL::Response::Element::Vector>]
      # @api public
      def array(opts)
        vector = Vector.new(opts)
        yield(vector) if block_given?
        @vectors << vector
      end

      # Returns the arrays/vectors contained in the response.
      # This is an alias to access @vectors
      # @see @vectors
      # 
      # @return [Array<WSDSL::Response::Element::Vector>]
      # @api public
      def arrays
        @vectors
      end

      # Defines a new element and yields the content of an optional block
      # Each new element is then stored in the elements array.
      #
      # @param [Hash] opts Options used to define the element
      # @option opts [String, Symbol] :name The element name
      # @option opts [String, Symbol] :type The optional type
      #
      # @yield [WSDSL::Response::Element] the newly created element
      # @example create an element called 'my_stats'.
      #   service.response do |response|
      #    response.element(:name => "my_stats", :type => 'Leaderboard')
      #   end
      #
      # @return [Array<WSDSL::Response::Element>]
      # @api public
      def element(opts={})
        el = Element.new(opts)
        yield(el) if block_given?
        @elements ||= []
        @elements << el
      end

      # Response element's attribute class
      # @api public
      class Attribute

        # @return [String, #to_s] The attribute's name.
        # @api public
        attr_reader :name

        # @return [Symbol, String, #to_s] The attribute's type such as boolean, string etc..
        # @api public
        attr_reader :type

        # @return [String] The documentation associated with this attribute.
        # @api public
        attr_reader :doc

        # @see {Attribute#new}
        # @return [Hash, Nil, Object] Could be a hash, nil or any object depending on how the attribute is created.
        # @api public
        attr_reader :opts

        # Takes a Hash or an Array and extract the attribute name, type
        # doc and extra options.
        # If the passed objects is a Hash, the name will be extract from
        # the first key and the type for the first value.
        # An entry keyed by :doc will be used for the doc and the rest will go
        # as extra options.
        #
        # If an Array is passed, the elements will be 'shifted' in this order:
        # name, type, doc, type
        #
        # @param [Hash, Array] o_params
        #
        # @api public
        def initialize(o_params)
          params = o_params.dup
          if params.is_a?(Hash)
            @name, @type = params.shift
            @doc  = params.delete(:doc) if params.has_key?(:doc)
            @opts = params
          elsif params.is_a?(Array)
            @name = params.shift
            @type = params.shift
            @doc  = params.shift
            @opts = params
          end
        end
      end

      # Array of objects inside an element
      # @api public
      class Vector

        # @api public
        attr_reader :name

        # @api public
        attr_reader :obj_type

        # @api public
        attr_reader :opts

        # @api public
        attr_accessor :required

        # @api public
        attr_accessor :attributes

        # A vector can have nested elements.
        # This value is nil by default.
        #
        # @return [NilClass, Array<WSDSL::Response::Element>]
        # @see #element
        # @api public
        attr_reader :elements

        # Initialize a Vector object, think about it as an array of objects of a certain type.
        # It is recommended to passthe type argument as a string so the constant doesn't need to be resolved.
        # In other words, if you say you are creating a vector of Foo objects, the Foo class doesn't need to be 
        # loaded yet. That makes service parsing easier and avoids dependency challenges.
        #
        # @param [Hash] opts A hash representing the vector information, usually a name and a type, both as strings
        # @option opts [String] :name The array's name
        # @option opts [Symbol, String] :type The type of the objects inside the array
        #
        # @example
        #   Vector.new(:name => 'player_creation_rating', :type => 'PlayerCreationRating')
        #
        # @api public
        def initialize(opts)
          opts[:required] ||= false
          @name       = opts.delete(:name) if opts.has_key?(:name)
          @obj_type   = opts.delete(:type) if opts.has_key?(:type)
          @required   = opts.has_key?(:required) ? opts[:required] : true
          @opts       = opts
          @attributes = []
        end

        # Sets a vector attribute
        #
        # @param (see Attribute#initialize)
        # @api public
        def attribute(opts)
          raise ArgumentError unless opts.is_a?(Hash)
          @attributes << Attribute.new(opts)
        end

        # Defines a new element and yields the content of an optional block
        # Each new element is then stored in the elements array.
        #
        # @param [Hash] opts Options used to define the element
        # @option opts [String, Symbol] :name The element name
        # @option opts [String, Symbol] :type The optional type
        #
        # @yield [WSDSL::Response::Element] the newly created element
        # @example create an element called 'my_stats'.
        #   service.response do |response|
        #    response.element(:name => "my_stats", :type => 'Leaderboard')
        #   end
        #
        # @return [Array<WSDSL::Response::Element>]
        # @api public
        def element(opts={})
          el = Element.new(opts)
          yield(el) if block_given?
          @elements ||= []
          @elements << el
        end

      end # of Vector
    end # of Element

  end # of Response
end
