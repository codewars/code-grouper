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

In this case, these snippets will not be grouped together. 

