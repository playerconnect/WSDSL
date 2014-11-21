class WSDSL

  class ResponseExceptions

    attr_reader :list

    def initialize
      @list = []
    end

    def document(klass, doc)
      @list << Doc.new(klass, doc)
    end

    def classes
      @list.collect(&:klass)
    end

  end

  # ResponseException::Doc DSL class
  # @api public
  class Doc

    # The exception class
    #
    # @return [Exception]
    # @api public
    attr_reader :klass

    # The documentation for the exception
    #
    # @return [String]
    # @api public
    attr_reader :doc

    def initialize(klass, doc='')
      @klass = klass
      @doc = doc
    end

  end
end