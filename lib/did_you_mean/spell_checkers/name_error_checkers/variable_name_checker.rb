# frozen-string-literal: true

require_relative "../../spell_checker"

module DidYouMean
  class VariableNameChecker
    attr_reader :name, :method_names, :lvar_names, :ivar_names, :cvar_names

    def self.create_initial_names_to_exclude_map
      initial_map = { 'foo' => [:fork, :for] }
      initial_map.default = []
      initial_map
    end
    private_class_method :create_initial_names_to_exclude_map

    if defined?(Ractor)
      def self.names_to_exclude_map
        Ractor.current[:__DidYouMean_VariableNameChecker_Names_To_Exclude__] ||= create_initial_names_to_exclude_map
      end
    else
      def self.names_to_exclude_map
        NAMES_TO_EXCLUDE
      end
    end

    NAMES_TO_EXCLUDE = create_initial_names_to_exclude_map

    # +VariableNameChecker::RB_RESERVED_WORDS+ is the list of all reserved
    # words in Ruby. They could be declared like methods are, and a typo would
    # cause Ruby to raise a +NameError+ because of the way they are declared.
    #
    # The +:VariableNameChecker+ will use this list to suggest a reversed word
    # if a +NameError+ is raised and found closest matches, excluding:
    #
    #   * +do+
    #   * +if+
    #   * +in+
    #   * +or+
    #
    # Also see +MethodNameChecker::RB_RESERVED_WORDS+.
    RB_RESERVED_WORDS = %i(
      BEGIN
      END
      alias
      and
      begin
      break
      case
      class
      def
      defined?
      else
      elsif
      end
      ensure
      false
      for
      module
      next
      nil
      not
      redo
      rescue
      retry
      return
      self
      super
      then
      true
      undef
      unless
      until
      when
      while
      yield
      __LINE__
      __FILE__
      __ENCODING__
    )
    Ractor.make_shareable(RB_RESERVED_WORDS) if defined?(Ractor)

    def initialize(exception)
      @name       = exception.name.to_s.tr("@", "")
      @lvar_names = exception.respond_to?(:local_variables) ? exception.local_variables : []
      receiver    = exception.receiver

      @method_names = receiver.methods + receiver.private_methods
      @ivar_names   = receiver.instance_variables
      @cvar_names   = receiver.class.class_variables
      @cvar_names  += receiver.class_variables if receiver.kind_of?(Module)
    end

    def corrections
      @corrections ||= SpellChecker
                     .new(dictionary: (RB_RESERVED_WORDS + lvar_names + method_names + ivar_names + cvar_names))
                     .correct(name) - VariableNameChecker.names_to_exclude_map[@name]
    end
  end
end
