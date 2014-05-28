require 'spec_helper'
require 'code_grouper'

describe CodeGrouper do
  base_code = <<-CODE
    function test(a, b, c){
      // your code goes here
    }
  CODE

  simple_code = <<-CODE
    function test(a, b, c){
      // your code goes here
      return a + b + c;
    }
  CODE

  simple_squeezed_code = <<-CODE
    function test(a,b,c) {
      // your code goes here
      return a + b + c;
    }
  CODE

  simple_alt_code = <<-CODE
    function test(a, b,c){
      return b+a+c
    }
  CODE

  complex_code = <<-CODE
    function test(a, b, c){
      // your code goes here
        var result = a + b;
      return result + c;
    }
  CODE

  real_code_sample_base = <<-CODE
    function squareSum(numbers){

    }
  CODE

  real_code_sample1 = <<-CODE
    function squareSum(numbers){
      var result = 0;
      for (var i = 0; i < numbers.length; i++) {
        result += (numbers[i] * numbers[i]);
      }
      return result;
    }
  CODE

  real_code_sample2 = <<-CODE
    function squareSum(numbers){
      var square = numbers.map(function(x){return Math.pow(x,2);})
      return square.reduce(function(total,x){return total+x;})
    }
  CODE

  real_code_sample3 = <<-CODE
    def squareSum(numbers)
      numbers.inject(0){|x,y| x = x + (y**2)}
    end
  CODE

  real_code_sample4 = <<-CODE
    def squareSum(numbers)
      numbers.map{|i|i**2}.inject(0,:+)
    end
  CODE

  # Identical to the previous one, but with additional comments and whitespace.
  real_code_sample4b = <<-CODE
    # A comment.
    def squareSum numbers

      numbers.map{ |i| i**2 }.inject(0, :+) # Another comment.

    end
  CODE

  real_code_sample5 = <<-CODE
    def squareSum(numbers)
      numbers.reject(0){|x,y| x = x + (y**2)}
    end
  CODE

  describe CodeGrouper::Grouper do

    it 'should group items' do
      grouper = CodeGrouper::Grouper.new(base_code)

      grouper.group(simple_code, {id: 1})
      grouper.group(simple_alt_code, {id: 2})
      grouper.group(simple_squeezed_code, {id: 3})
      grouper.group(complex_code, {id: 4})
      grouper.group(simple_alt_code, {id: 5})
      grouper.group(simple_alt_code, {id: 5}) # this one should be ignored because its the same code with the same id

      grouper.groupings.size.should == 2
      grouper.groupings.first.member_count.should == 4
      grouper.groupings.first.data.size.should == 4
      grouper.groupings.first.data.last[:id].should == 5

      # variations should be 2 not 3 because they are variations grouper.groupings.first.code
      grouper.groupings.first.variations.size.should == 2
      grouper.groupings.first.variations.first[:data].size.should == 2
      grouper.groupings.first.variations.first[:count].should == 2
    end

    it 'should not group items that arent similar enough' do
      grouper = CodeGrouper::Grouper.new

      grouper.group(real_code_sample1)
      grouper.groupings.size.should == 1
      grouper.group(real_code_sample2)
      grouper.groupings.size.should == 2
      grouper.group(real_code_sample3)
      grouper.groupings.size.should == 3
      grouper.group(real_code_sample4)
      grouper.groupings.size.should == 4
      grouper.group(real_code_sample5)

      grouper.groupings.size.should == 4
    end

    it 'should group items using reduced code matching when proxmity == 0' do
      grouper = CodeGrouper::Grouper.new(base_code, 0)

      grouper.group(simple_code)
      grouper.group(simple_squeezed_code)
      grouper.group(simple_alt_code)

      grouper.groupings.size.should == 2
    end
  end

  describe 'proximity' do
    it 'should not be similar for code that is different' do
      example = CodeGrouper.new(simple_code, complex_code, base_code)
      example.similar?.should be_false
    end

    it 'should be similar for code that is basically the same exact thing' do
      example = CodeGrouper.new(simple_code, simple_alt_code, base_code)
      example.similar?.should be_true

      example.base_code = nil
      example.similar?.should be_false
    end
  end

  describe 'difference' do
    it 'should return zero difference for strings that are the same' do
      CodeGrouper.difference(simple_code, simple_squeezed_code, base_code).should == 0
    end

    it 'should not match 2 strings of similar weighted values but not similar code' do
      CodeGrouper.difference(real_code_sample1, real_code_sample2, real_code_sample_base).abs.should > 10
      CodeGrouper.difference(real_code_sample3, real_code_sample4).abs.should > 4
    end
  end

  describe 'difference' do
    it 'returns a difference of zero when code is identical' do
      sample = 'returna+b+c'
      CodeGrouper.difference(sample, sample).should == 0
    end

    it 'stays stable regardless of code size' do
      samples = ['returna+b+c', 'returnx+y+z']
      d1 = CodeGrouper.difference(*samples)
      d2 = CodeGrouper.difference(*samples.map { |x| x * 20 })
      d1.should == d2
    end

    it 'takes size difference into account' do
      samples = ['returna+b+c', 'returnx+y+z', 'returnalpha+beta+delta']
      d1 = CodeGrouper.difference(*samples[0,2])
      d2 = CodeGrouper.difference(*samples[1,2])
      d1.should < d2
    end

    it 'gives a higher score for more differences' do
      samples = ['returna+b+c', 'returna+b+d', 'returnx+y+z']
      d1 = CodeGrouper.difference(*samples[0,2])
      d2 = CodeGrouper.difference(*samples[1,2])
      d1.should < d2
    end

    it "doesn't care about the order of the samples" do
      samples = ['returna+b+c', 'returnx+y+z']
      d1 = CodeGrouper.difference(*samples)
      d2 = CodeGrouper.difference(*samples.reverse)
      d1.should == d2
    end

    it 'cares more about a small distance when the samples are small' do
      samples = %w(a b)
      d1 = CodeGrouper.difference(*samples)
      d2 = CodeGrouper.difference(*samples.map { |s| s + ('X' * 2) })
      d3 = CodeGrouper.difference(*samples.map { |s| s + ('X' * 3) })
      d1.should > d2
      d2.should > d3
    end
  end


  describe 'reduce and strip' do
    context 'reduce' do
      it 'should reduce a simple difference in code' do
        CodeGrouper.reduce(simple_code, base_code).should == 'returna+b+c'
        CodeGrouper.reduce(simple_alt_code, base_code).should == 'returnb+a+c'
      end

      it 'should ignore whitespace differences' do
        CodeGrouper.reduce(simple_squeezed_code, base_code).should == 'returna+b+c'
      end

      it 'should reduce ruby specific code' do
        CodeGrouper.reduce("def a; end").should == 'defaend'
        CodeGrouper.reduce("def a; end", nil, 'ruby').should_not == 'defaend'

        CodeGrouper.reduce("collect(0)").should == "collect0"
        CodeGrouper.reduce("collect(0)", nil, 'ruby').should_not == 'collect0'
        CodeGrouper.reduce(real_code_sample4, nil, 'ruby').should == CodeGrouper.reduce(real_code_sample4b, nil, 'ruby')
        CodeGrouper.reduce(real_code_sample4, nil, 'ruby').should == CodeGrouper.reduce(real_code_sample4b.gsub(/^ */, ''), nil, 'ruby')
      end
    end

    context 'strip' do
      it 'should strip a simple difference in code' do
        CodeGrouper.strip_code(simple_code, base_code).should == 'return a + b + c;'
      end

      it 'should ignore whitespace differences' do
        CodeGrouper.strip_code(simple_squeezed_code, base_code).should == 'function test(a,b,c) {return a + b + c;'
      end
    end
  end
end