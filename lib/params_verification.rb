# ParamsVerification module.
# Written to verify a service params without creating new objects.
# This module is used on all requests requiring validation and therefore performance
# security and maintainability are critical.
#
# @api public
module ParamsVerification

  class ParamError        < StandardError; end #:nodoc
  class NoParamsDefined   < ParamError; end #:nodoc
  class MissingParam      < ParamError; end #:nodoc
  class UnexpectedParam   < ParamError; end #:nodoc
  class InvalidParamType  < ParamError; end #:nodoc
  class InvalidParamValue < ParamError; end #:nodoc

  # An array of validation regular expressions.
  # The array gets cached but can be accessed via the symbol key.
  #
  # @return [Hash] An array with all the validation types as keys and regexps as values.
  # @api public
  def self.type_validations
    @type_validations ||= { :integer  => /^-?\d+$/,
                            :float    => /^-?(\d*\.\d+|\d+)$/,
                            :decimal  => /^-?(\d*\.\d+|\d+)$/,
                            :datetime => /^[-\d:T\s]+$/,  # "T" is for ISO date format
                            :boolean  => /^(1|true|TRUE|T|Y|0|false|FALSE|F|N)$/,
                            #:array    => /,/
                          }
  end

  # Validation against each required WSDSL::Params::Rule
  # and returns the potentially modified params (with default values)
  #
  # @param [Hash] params The params to verify (incoming request params)
  # @param [WSDSL::Params] service_params A Playco service param compatible object listing required and optional params
  # @param [Boolean] ignore_unexpected Flag letting the validation know if unexpected params should be ignored
  #
  # @return [Hash]
  #   The passed params potentially modified by the default rules defined in the service.
  #
  # @example Validate request params against a service's defined param rules
  #   ParamsVerification.validate!(request.params, @service.defined_params)
  #
  # @api public
  def self.validate!(params, service_params, ignore_unexpected=false)

    # Verify that no garbage params are passed, if they are, an exception is raised.
    # only the first level is checked at this point
    unless ignore_unexpected
      unexpected_params?(params, service_params.param_names)
    end

    # Create a duplicate of the params hash that uses symbols as keys,
    # while preserving the original hash
    updated_params = symbolify_keys(params)

    # Required param verification
    service_params.list_required.each do |rule|
      updated_params = validate_required_rule(rule, updated_params)
    end

    # Set optional defaults if any optional
    service_params.list_optional.each do |rule|
      updated_params = run_optional_rule(rule, updated_params)
    end

    # check the namespaced params
    service_params.namespaced_params.each do |param|
      param.list_required.each do |rule|
        updated_params = validate_required_rule(rule, updated_params, param.space_name.to_s)
      end
      param.list_optional.each do |rule|
        updated_params = run_optional_rule(rule, updated_params, param.space_name.to_s)
      end

    end

    # verify nested params, only 1 level deep tho
    params.each_pair do |key, value|
      # We are now assuming a file param is a hash due to Rack::Mulitpart.parse_multipart
      # turns this data into a hash, but param verification/DSL dont expect this or define this behavior and it shouldn't.
      # so special case it if its a file type and the value is a hash.
      if value.is_a?(Hash) && type_for_param(service_params, key) != :file
        namespaced = service_params.namespaced_params.find{|np| np.space_name.to_s == key.to_s}
        raise UnexpectedParam, "Request included unexpected parameter: #{key}" if namespaced.nil?
        unexpected_params?(params[key], namespaced.param_names)
      end
    end

    updated_params
  end


  private

  # Create a copy of hash that enforces the usage of symbols as keys
  #
  #
  # @params [Hash] The hash to copy
  #
  # @return [Hash] A copy of the given hash, but with all keys forced to be symbols
  #
  # @api private
  def self.symbolify_keys(a_hash={})
    new_hash = {}
    a_hash.each do |k,v|
      if v.class.to_s =~ /^Hash/
        new_hash[k.to_sym] = symbolify_keys(v)
      else
        new_hash[k.to_sym] = v
      end
    end
    new_hash
  end


  # Validate a required rule against a list of params passed.
  #
  #
  # @param [WSDSL::Params::Rule] rule The required rule to check against.
  # @param [Hash] params The request params.
  # @param [String] namespace Optional param namespace to check the rule against.
  #
  # @return [Hash]
  #   A hash representing the potentially modified params after going through the filter.
  #
  # @api private
  def self.validate_required_rule(rule, params, namespace=nil)
    param_name  = rule.name.to_sym
    namespace = namespace.to_sym if namespace
    param_value, namespaced_params = extract_param_values(params, param_name, namespace)

    # Checks presence
    if !(namespaced_params || params).keys.include?(param_name)
      raise MissingParam, "'#{rule.name}' is missing - passed params: #{params.inspect}."
    end

    # check for nulls in params that don't allow them
    check_for_null(param_name, param_value, rule, params, namespace)

    # run the common set of rules used for any non nil value
    params = self.run_when_not_nil(rule, params, namespace)

    # Returns the updated params
    params
  end


  # Extract the param valie and the namespaced params
  # based on a passed namespace and params
  #
  # @param [Hash] params The passed params to extract info from.
  # @param [String] param_name The param name to find the value.
  # @param [NilClass, String] namespace the params' namespace.
  # @return [Arrays<Object, String>]
  #
  # @api private
  def self.extract_param_values(params, param_name, namespace=nil)
    # Namespace check
    if namespace == '' || namespace.nil?
      [params[param_name], nil]
    else
      # puts "namespace: #{namespace} - params #{params[namespace].inspect}"
      namespaced_params = params[namespace]
      if namespaced_params
        [namespaced_params[param_name], namespaced_params]
      else
        [nil, namespaced_params]
      end
    end
  end


  # Validate non nil values. They may have been optional if left blank, but
  # when they are nil they are validated.
  #
  #
  # @param [WSDSL::Params::Rule] rule The required rule to check against.
  # @param [Hash] params The request params.
  # @param [String] namespace Optional param namespace to check the rule against.
  #
  # @return [Hash]
  #   A hash representing the potentially modified params after going through the filter.
  #
  # @api private
  def self.run_when_not_nil(rule, params, namespace=nil)
    param_name  = rule.name.to_sym
    namespace = namespace.to_sym if namespace
    param_value, namespaced_params = extract_param_values(params, param_name, namespace)

    # checks type
    if rule.options[:type]
      verify_cast(param_name, param_value, rule.options[:type])
      param_value = type_cast_value(rule.options[:type], param_value)
      # update the params hash with the type cast value
      if namespace
        params[namespace] ||= {}
        params[namespace][param_name] = param_value
      else
        params[param_name] = param_value
      end
    end

    # checks the value against a whitelist style 'in'/'options' list
    if rule.options[:options] || rule.options[:in]
      choices = rule.options[:options] || rule.options[:in]
      validate_inclusion_of(param_name, param_value, choices)
    end

    # enforce a minimum numeric value
    if rule.options[:minvalue]
      min = rule.options[:minvalue]
      raise InvalidParamValue, "Value for parameter '#{param_name}' is lower than the min accepted value (#{min})." if param_value.to_i < min
    end

    # enforce a maximum numeric value
    if rule.options[:maxvalue]
      max = rule.options[:maxvalue]
      raise InvalidParamValue, "Value for parameter '#{param_name}' is higher than the max accepted value (#{max})." if param_value.to_i > max
    end

    # enforce a minimum string length
    if rule.options[:minlength]
      min = rule.options[:minlength]
      raise InvalidParamValue, "Length of parameter '#{param_name}' is shorter than the min accepted value (#{min})." if param_value.to_s.length < min
    end
    
    # enforce a maximum string length
    if rule.options[:maxlength]
      max = rule.options[:maxlength]
      raise InvalidParamValue, "Length of parameter '#{param_name}' is longer than the max accepted value (#{max})." if param_value.to_s.length > max
    end

    # Return the modified params
    params
  end


  # @param [#WSDSL::Params::Rule] rule The optional rule
  # @param [Hash] params The request params
  # @param [String] namespace An optional namespace
  # @return [Hash] The potentially modified params
  #
  # @api private
  def self.run_optional_rule(rule, params, namespace=nil)
    param_name  = rule.name.to_sym
    namespace = namespace.to_sym if namespace
    param_value, namespaced_params = extract_param_values(params, param_name, namespace)

    # Use a default value if one is available and the submitted param value is nil
    if param_value.nil? && rule.options[:default]
      param_value = rule.options[:default]
      if namespace
        params[namespace] ||= {}
        params[namespace][param_name] = param_value
      else
        params[param_name] = param_value
      end
    end

    # If the value is still null after possibly being given a default,
    # reject it if "null" is explicitly set to false.
    check_for_null(param_name, param_value, rule, params, namespace)

    # run the common set of rules used for any non nil value
    params = self.run_when_not_nil(rule, params, namespace) if param_value

    params
  end


  def self.unexpected_params?(params, param_names)
    # Raise an exception unless no unexpected params were found
    unexpected_keys = (params.keys - param_names)
    unless unexpected_keys.empty?
      raise UnexpectedParam, "Request included unexpected parameter(s): #{unexpected_keys.join(', ')}"
    end
  end


  def self.type_cast_value(type, value)
    case type
    when :integer
      value.to_i
    when :float, :decimal
      value.to_f
    when :string
      value.to_s
    when :boolean
      if value.is_a? TrueClass
        true
      elsif value.is_a? FalseClass
        false
      else
        case value.to_s
        when /^(1|true|TRUE|T|Y)$/
          true
        when /^(0|false|FALSE|F|N)$/
          false
        else
          raise InvalidParamValue, "Could not typecast boolean to appropriate value"
        end
      end
    # An array type is a comma delimited string, we need to cast the passed strings.
    when :array
      value.respond_to?(:split) && !value.respond_to?(:compact) ? value.split(',') : value
    when :binary, :array, :file
      value
    else
      value
    end
  end

  # Checks that the value's type matches the expected type for a given param
  #
  # @param [Symbol, String] Param name used if the verification fails and that an error is raised.
  # @param [#to_s] The value to validate.
  # @param [Symbol] The expected type, such as :boolean, :integer etc...
  # @raise [InvalidParamType] Custom exception raised when the validation isn't found or the value doesn't match.
  #
  # @return [Nil]
  # @api public
  # TODO raising an exception really isn't a good idea since it forces the stack to unwind.
  # More than likely developers are using exceptions to control the code flow and a different approach should be used.
  # Catch/throw is a bit more efficient but is still the wrong approach for this specific problem.
  def self.verify_cast(name, value, expected_type)
    validation = ParamsVerification.type_validations[expected_type.to_sym]
    unless validation.nil? || value.to_s =~ validation
      raise InvalidParamType, "Value for parameter '#{name}' (#{value}) is of the wrong type (expected #{expected_type})"
    end
  end

  def self.type_for_param(service_params, name)
    (service_params.list_required + service_params.list_optional).each do |rule|
      if rule.name.to_s == name.to_s
        return rule.options[:type]
      end
    end
  end

  def self.validate_inclusion_of(name, value, choices)
    return unless choices && value
    valid = value.is_a?(Array) ? (value & choices == value) : choices.include?(value)
    unless valid
      raise InvalidParamValue, "Value for parameter '#{name}' (#{value}) is not in the allowed set of values."
    end
  end

  # if ":null => false" is explicitly set, null values will be rejected (even
  # for optional params)
  def self.check_for_null(param_name, param_value, rule, params, namespace)
    # don't check for null against params that weren't even submitted
    # return unless params && params.size > 0
    if namespace
      return unless params.has_key?(namespace)
      params = params[namespace]
    end
    return unless params && params.has_key?(param_name)

    # if 'null' is found in the ruleset and set to 'false' (default is 'true' to allow null),
    # then confirm that the submitted value isn't nil or empty
    if rule.options.has_key?(:null) && rule.options[:null] == false &&
       (param_value.nil? || param_value == '' || (param_value.respond_to?(:size) && param_value.size == 0))
      raise InvalidParamValue, "Value for parameter '#{param_name}' cannot be null - passed params: #{params.inspect}."
    end
  end
end
