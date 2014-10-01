code-grouper
============

The purpose of this gem is to match and group related snippets of code for various languages. For example, the follow snippets should be matched together:

```ruby
def add(a, b)
  a + b
end
```
```ruby
def add(i, x)
  i + x
end
```

The intent of this gem is to not just to reduce code down to its most minimal form. An attempt to preserve good coding conventions is made. For example, the following snippets are identical except for the variable names. One uses descriptive names while the other doesn't:

```javascript
function sortList (sortBy, list) {
  return list.sort(function(a, b){
    return a[sortBy] < b[sortBy]
  });
}
```

```javascript
function sortList (s, l) {
  return l.sort(function(a, b){
    return a[s] < b[s]
  });
}
```

In this case, these snippets will not be grouped together. Ideally, this project would be able to take good coding practices into account, and do things like group solutions with one letter variables together, and also group solutions that use descriptive names together, so that there would be two separate groups. Currently the code grouping does not handle this. 

### How to use

See `code_comparer_spec.rb` for usage examples. 

### Refactoring Opportunities

The codebase has some technical debt in it after going through a few different experimentations on how to group code. Here is a list of a few things that could be streamlined:

- [ ] `base_code` should not be necessary
- [ ] `similar?` and the related `difference` code is not currently being used on Codewars. Unless someone finds a good use for it, it can likely just be removed.
- [ ] There was an attempt to disassemble ruby code as a way to group - this method was buggy and inconsistent from the other languages and is currently commented out. 

