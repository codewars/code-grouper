class CodeComparer
  DEFAULT_PROXIMITY = Integer(ENV['CODE_COMPARER_PROXIMITY'] || 20)

  attr_reader :base_code, :original_code, :code

  def initialize(original_code, code, base_code = nil)
    @original_code = original_code
    @code = code
    @base_code = base_code
  end

  def same?
    code_reduced == original_code_reduced
  end

  def similar?(proximity = DEFAULT_PROXIMITY)
    difference.positive <= proximity and length_difference.positive <= [proximity / 2, 5].min
  end

  def difference
    original_code_hash_sum - code_hash_sum
  end

  def length_difference
    original_code_reduced.length - code_reduced.length
  end

  def original_code=(val)
    @original_code = val
    @original_code_hash_sum = nil
    @original_code_reduced = nil
  end

  def base_code=(val)
    @base_code = val
    @code_hash_sum = nil
    @original_code_hash_sum = nil
    @code_reduced = nil
    @original_code_reduced = nil
  end

  def code=(val)
    @code = val
    @code_hash_sum = nil
    @code_reduced = nil
  end

  def code_hash_sum
    @code_hash_sum ||= CodeComparer.hash_sum(code, base_code)
  end

  def original_code_hash_sum
    @original_code_hash_sum ||= CodeComparer.hash_sum(original_code, base_code)
  end

  def original_code_reduced
    @original_code_reduced ||= CodeComparer.reduce(original_code, base_code)
  end

  def code_reduced
    @code_reduced ||= CodeComparer.reduce(code, base_code)
  end

  class << self
    # returns the difference between the original_code and code.
    # @param [String] original_code The basis of the comparison
    # @param [String] code
    # @param [String] base_code optional value that if provided will be code that is stripped out of the other code strings
    def difference(original_code, code, base_code = nil, language = nil)
      hash_sum(original_code, base_code, language) - hash_sum(code, base_code, language)
    end

    # reduces the code and sums the characters based off of a weighted character scale
    def hash_sum(code, base_code = nil, language = nil)
      hash_sum_reduced(reduce(code, base_code, language))
    end

    def hash_sum_reduced(reduced_code)
      reduced_code.codepoints.inject(0, :+)
    end

    def reduce(code, base_code = nil, language = nil)
      if language == 'ruby'
        return RubyVM::InstructionSequence.compile(code).disasm.gsub!(/[ \t]+/, ' ')
      end

      regex = /[ ;,(){}\t'"]/

      reduced = code.gsub(regex, '')

      language_subs(language).each do |rx, val|
        reduced.gsub!(rx, val)
      end

      if base_code
        base_code.chomp.split(/\n/).each do |line|
          reduced.sub!(line.gsub(regex, ''), '')
        end
      end

      reduced.gsub(/\n/, '')
    end

    def language_subs(language)
      subs = []

      if language
        case language.to_sym
          #when :javascript, :js
          when :coffeescript
            subs << [' == ', ' is ']
            subs << [' !== ', ' is not ']
        end
      end

      subs
    end

    def strip_code(code, base_code = nil)
      reduced = code
      if base_code
        base_code.chomp.split(/\n/).each do |line|
          reduced.sub!(line.strip, '')
        end
      end

      final = ''
      reduced.chomp.split(/\n/).each do |line|
        final += line.strip
      end

      final
    end
  end

  # used to group
  class Grouper
    attr_reader :groupings, :proximity

    def initialize(base_code = nil, proximity = DEFAULT_PROXIMITY)
      @base_code = base_code
      @groupings = []
      @proximity = proximity
    end

    def find_grouping_by_data(data)
      @groupings.each do |group|
        return group if group.data.include?(data)
      end
      nil
    end

    def find_grouping(reduced_code, hash_sum)
      hash_sum ||= CodeComparer.hash_sum_reduced(reduced_code) if proximity > 0

      @groupings.each do |group|
        if proximity == 0
          return group if group.reduced_code == reduced_code
        else
          return group if (group.hash_sum - hash_sum).positive < @proximity
        end
      end

      nil
    end

    def group(code, data = nil)
      reduced = CodeComparer.reduce(code, @base_code)
      hash_sum = CodeComparer.hash_sum_reduced(reduced)

      grouping = find_grouping(reduced, hash_sum)
      # if we found an existing group than just add the data to it
      if grouping
        grouping.add(code, data)
      # otherwise create a new group
      else
        grouping = Grouping.new(code, hash_sum, reduced, data)
        @groupings << grouping
      end

      grouping
    end

    class Grouping
      attr_reader :code, :hash_sum, :data, :match_data, :match_count, :variations, :reduced_code
      attr_accessor :member_count

      def initialize(code, hash_sum, reduced_code, data = nil)
        @code = code
        @hash_sum = hash_sum
        @reduced_code = reduced_code

        @data = []
        @match_data = [] # used for tracking data that is related to an exact hash_sum match (similar to variation data for variations)
        if data
          @data << data
          @match_data << data
        end

        @member_count = 1
        @match_count = 1
        @variations = []
      end

      def add(code, data)
        # use the data id key to determine if this is a duplicate - if so ignore it
        if data.try(:[], :id) and @data.find {|d| d[:id] == data[:id]}
          return false
        end

        unless @code == code
          variation = @variations.find {|v| v[:code] == code}
          if variation
            variation[:count] += 1
          else
            variation = {code: code, data: [], count: 1}
            @variations << variation
          end

          variation[:data] << data if data
        end

        @member_count += 1
        @match_count += 1 unless variation

        if data
          @data << data
          @match_data << data unless variation
        end

        true
      end
    end
  end

end