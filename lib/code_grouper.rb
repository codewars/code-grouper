class CodeGrouper
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
    self.class.reduced_difference(original_code_reduced, code_reduced) <= proximity && length_difference.abs <= [proximity / 2, 5].min
  end

  def length_difference
    original_code_reduced.length - code_reduced.length
  end

  def original_code=(val)
    @original_code = val
    @original_code_reduced = nil
  end

  def base_code=(val)
    @base_code = val
    @code_reduced = nil
    @original_code_reduced = nil
  end

  def code=(val)
    @code = val
    @code_reduced = nil
  end

  def original_code_reduced
    @original_code_reduced ||= CodeGrouper.reduce(original_code, base_code)
  end

  def code_reduced
    @code_reduced ||= CodeGrouper.reduce(code, base_code)
  end

  class << self
    # returns the difference between the original_code and code.
    # @param [String] original_code The basis of the comparison
    # @param [String] code
    # @param [String] base_code optional value that if provided will be code that is stripped out of the other code strings
    def difference(original_code, code, base_code = nil, language = nil)
      reduced_difference reduce(original_code, base_code, language), reduce(code, base_code, language)
    end

    def reduced_difference(original_code, code)
      olen = original_code.length
      clen = code.length
      dlen = (olen - clen).abs
      d = edit_distance(original_code, code)
      (
        (d * 50) / Math.sqrt(clen * olen)
      )
    end

    # A relatively straightforward implementation of the Wagner-Fischer algorithm for calculating Levenshtein distance between two strings.
    def edit_distance(a, b)
      res = (0..a.length).map { |*| Array.new b.length }
      achars = a.codepoints#.sort!
      bchars = b.codepoints#.sort!
      res[0][0] = 0
      achars.each_with_index { |c,i| res[i+1][0] = i + 1 }
      bchars.each_with_index { |c,i| res[0][i+1] = i + 1 }
      achars.each_with_index { |ac,i|
        bchars.each_with_index { |bc,j|
          if ac == bc
            res[i+1][j+1] = res[i][j]
          else
            res[i+1][j+1] = [res[i][j+1], res[i+1][j], res[i][j]].min + 1
          end
        }
      }
      res.last.last
    end

    def reduce(code, base_code = nil, language = nil)
      # if language == 'ruby'
      #   begin
      #     # FIXME:  We'll be splitting the languages into different classes.
      #     return RubyVM::InstructionSequence.
      #       compile(code).disasm.tap { |r|
      #         r.gsub!(/[ \t]+/, ' ')
      #         r.gsub!(/\( *\d+\) *$/, '') # Strip line numbers.
      #       }
      #   rescue
      #   end
      # end

      regex = /[ ;,(){}\t'"]/

      reduced = strip_comments(code, language).gsub(regex, '')

      if base_code
        base_code.chomp.split(/\n/).each do |line|
          reduced.sub!(line.gsub(regex, ''), '')
        end
      end

      language_subs(language).each do |rx, val|
        reduced.gsub!(rx, val)
      end

      reduced.gsub(/\n/, '')
    end

    # Strips comments about as well as you can without using a real parser.
    def strip_comments(code, language)
      return code unless language && code
      code = code.dup
      comment_rx = lambda { |c| Regexp.compile("^\s+#{Regexp.escape(c)}.*") }

      case language.to_sym
      when :ruby, :coffeescript, :python
        code.gsub! comment_rx['#'], ''
      when :javascript, :js
        code.gsub! comment_rx['//'], ''
      end

      code
    end

    def language_subs(language)
      subs = []

      if language
        case language.to_sym
          #when :javascript, :js
          when :coffeescript
            subs << [' == ', ' is ']
            subs << [' !== ', ' is not ']

          when :ruby
            subs << ['kind_of?', 'is_a?']
            subs << ['length', 'size']
            subs << ['delete_if', 'reject']
            subs << ['delete_if!', 'reject!']
            subs << ['keep_if', 'select']
            subs << ['collect', 'map']
            subs << ['member?', 'include?']
        end
      end

      subs
    end

    def strip_code(code, base_code = nil)
      reduced = code.dup
      if base_code
        base_code.split(/\n/).each do |line|
          reduced.sub!(line.strip, '')
        end
      end
      
      reduced.gsub!(/^[ \t]*|[ \t]*$/, '')
      reduced.gsub!(/\n/, '')

      reduced
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

    def find_grouping(reduced_code)
      @groupings.each do |group|
        if proximity == 0
          return group if group.reduced_code == reduced_code
        else

          return group if CodeGrouper.reduced_difference(group.reduced_code, reduced_code) < @proximity
        end
      end

      nil
    end

    def group(code, data = nil)
      reduced = CodeGrouper.reduce(code, @base_code)

      grouping = find_grouping(reduced)
      # if we found an existing group than just add the data to it
      if grouping
        grouping.add(code, data)
      # otherwise create a new group
      else
        grouping = Grouping.new(code, reduced, data)
        @groupings << grouping
      end

      grouping
    end

    class Grouping
      attr_reader :code, :data, :match_count, :variations, :reduced_code
      attr_accessor :member_count

      def initialize(code, reduced_code, data = nil)
        @code = code
        @reduced_code = reduced_code

        @data = []
        if data
          @data << data
        end

        @member_count = 1
        @match_count = 1
        @variations = []
      end

      def add(code, data)
        return false unless data

        # use the data id key to determine if this is a duplicate - if so ignore it
        if @data.find {|d| d[:id] == data[:id]}
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
        end

        true
      end
    end
  end

end
