require 'spec_helper'
require 'code_comparer'

describe CodeComparer do
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

  real_code_sample5 = <<-CODE
    def squareSum(numbers)
      numbers.reject(0){|x,y| x = x + (y**2)}
    end
  CODE

  describe CodeComparer::Grouper do

    it 'should group items' do
      grouper = CodeComparer::Grouper.new(base_code)

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

      grouper.groupings.first.match_data.size.should == 1
      grouper.groupings.first.match_count.should == 1

      # variations should be 2 not 3 because they are variations grouper.groupings.first.code
      grouper.groupings.first.variations.size.should == 2
      grouper.groupings.first.variations.first[:data].size.should == 2
      grouper.groupings.first.variations.first[:count].should == 2
    end

    it 'should not group items that arent similar enough' do
      grouper = CodeComparer::Grouper.new

      grouper.group(real_code_sample1)
      grouper.group(real_code_sample2)
      grouper.group(real_code_sample3)
      grouper.group(real_code_sample4)
      grouper.group(real_code_sample5)

      grouper.groupings.size.should == 4
    end

    it 'should group items using reduced code matching when proxmity == 0' do
      grouper = CodeComparer::Grouper.new(base_code, 0)

      grouper.group(simple_code)
      grouper.group(simple_squeezed_code)
      grouper.group(simple_alt_code)

      grouper.groupings.size.should == 2
    end
  end

  describe 'proximity' do
    it 'should not be similar for code that is different' do
      example = CodeComparer.new(simple_code, complex_code, base_code)
      example.similar?.should be_false
    end

    it 'should be similar for code that is basically the same exact thing' do
      example = CodeComparer.new(simple_code, simple_alt_code, base_code)
      example.similar?.should be_true

      example.base_code = nil
      example.similar?.should be_false
    end
  end

  describe 'difference' do
    it 'should return zero difference for strings that are the same' do
      CodeComparer.difference(simple_code, simple_squeezed_code, base_code).should == 0
    end

    it 'should not match 2 strings of similar weighted values but not similar code' do
      CodeComparer.difference(real_code_sample1, real_code_sample2, real_code_sample_base).positive.should > 10
      CodeComparer.difference(real_code_sample3, real_code_sample4).positive.should > 4
    end
  end

  describe 'hash_sum' do
    it 'should return the same sum for the same chars but in different order' do
      sum1 = CodeComparer.hash_sum('returna+b+c')
      sum2 = CodeComparer.hash_sum('returnb+a+c')
      sum1.should == sum2
    end

    it 'should always return a value greater than 1 unless only whitespace is passed in' do
      CodeComparer.hash_sum('').should == 0
      CodeComparer.hash_sum(' ').should == 0
      CodeComparer.hash_sum('a').should > 0
    end

    it 'should properly reduce a set of code and return the correct hash_sum value' do
      CodeComparer.hash_sum(simple_code, base_code) == 52
    end
  end


  describe 'reduce and strip' do
    context 'reduce' do
      it 'should reduce a simple difference in code' do
        CodeComparer.reduce(simple_code, base_code).should == 'returna+b+c'
        CodeComparer.reduce(simple_alt_code, base_code).should == 'returnb+a+c'
      end

      it 'should ignore whitespace differences' do
        CodeComparer.reduce(simple_squeezed_code, base_code).should == 'returna+b+c'
      end

      it 'should reduce ruby specific code' do
        CodeComparer.reduce("def a; end").should == 'defaend'
        CodeComparer.reduce("def a; end", nil, 'ruby').should == 'a'

        CodeComparer.reduce("collect(0)").should == "collect0"
        CodeComparer.reduce("collect(0)", nil, 'ruby').should == 'map0'
      end
    end

    context 'strip' do
      it 'should strip a simple difference in code' do
        CodeComparer.strip_code(simple_code, base_code).should == 'return a + b + c;'
      end

      it 'should ignore whitespace differences' do
        CodeComparer.strip_code(simple_squeezed_code, base_code).should == 'function test(a,b,c) {return a + b + c;'
      end
    end
  end
end