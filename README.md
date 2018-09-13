# Enumpath [![Build Status][ci-image]][ci] [![Gem Version][version-image]][version] [![Reviewed by Hound][hound-badge-image]][hound]

A JSONPath-compatible library for safely navigating nested Ruby objects using path expressions.

## Introduction

Enumpath is an implementation of the [JSONPath][jsonpath] spec for Ruby objects, plus some added sugar. It's like Ruby's native `Enumerable#dig` method, but fancier. It is designed for situations where you need to provide a dynamic way of describing a complex path through nested enumerable objects. This makes it exceptionally well suited for flexible ETL (Extract, Transform, Load) processes by allowing you to define paths through your data in a simple, easily readable, easily storable syntax.

Enumpath path expressions look like this:

```
$.pets.cats.0.name

$.pets[cats,dogs].*.name

pets..name

['pets']..[?(@.age > 10)].name

..age

pets.cats.-1
```

Enumpath has the following benefits over vanilla `Enumerable#dig`:

- Paths can be described as simple strings
- It's smart enough to figure out which path segments are integer indexes versus symbolic keys versus string keys
- It enables the use of wildcard, recursive descent, filter, subscript, union, and slice operators to describe complex paths through the data

Like `Enumerable#dig`, Enumpath protects against missing path segments and returns safely if the full path cannot be resolved.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'enumpath'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install enumpath

## Usage

Enumpath exposes a simple interface via `Enumpath.apply` that takes a path and an enumerable.

```ruby
party = { food: %w[pizza tacos] }
Enumpath.apply('food.0', party) # => ["pizza"]
```

The result of `Enumpath.apply` is an array of values that were extracted according to the path. Technically it's an instance of `Enumpath::Results` which is an Array-like object that allows you to chain further calls to `.apply` like this:

```ruby
party = { food: %w[pizza tacos] }
results = Enumpath.apply('food.*', party) # => ["pizza", "tacos"]
results.apply("[?(@ == 'pizza')]") # => ["pizza"]
```

In the event that the path doesn't match anything, an empty results set is returned:

```ruby
party = { food: %w[pizza tacos] }
Enumpath.apply("drinks.*", party) # => []
```

> This is a thoughtful deviation from the original JSONPath spec which would return `false` on no matches.

## Operator Reference

Enumpath currently implements the following path operators:

operator | summary | basic examples
:---: | --- | ---
`$` | **Root**; only valid at the beginning of a path and it is entirely optional | `$.puppies` is equivalent to `puppies`
`.` or `[]` | **[Child](#child-operator)**; can be dot notation or bracket, and bracketed child operators can optionally be wrapped in single quotes | `locations`, `0`, `[departments]`, and `['human resources']` are all valid child operators
`*` | **[Wildcard](#wildcard-operator)**; applies the remaining path to each member of the current enumerable | `children.*.name` would result in an array containing the names of all the children
`..` | **[Recursive descent](#recursive-descent-operator)**; applies the remaining path to all members at every level of the current enumerable, including to the current enumerable itself | `..name` would find all the `name` members all the way down through the enumerable regardless of nesting level
`[start:end:step]` | **[Slice](#slice-operator)**; similar in functionality to Ruby's `Array#slice` method with the addition of a step argument | `[1:8:2]` would operate on indices 1, 3, 5, and 7
`[child1,child2[,...]]` | **[Union](#union-operator)**; combines the results from multiple child operators | `authors.*[first_name,last_name]` is equivalent to `authors.*.first_name` + `authors.*.last_name`
`?()` | **[Filter expression](#filter-expression-operator)**; evaluates boolean expressions against the current enumerable; only the members of enumerable that meet the criteria are passed through | `[?(@.price > 10 && @.price <= 20 )]` would return all items whose price is greater than 10 and less than or equal to 20
`()` | **[Subscript expression](#subscript-expression-operator)**; evaluates an expression as a subscript on the current enumerator | `[(@.length - 1)]` would apply a child operator equal to the `#length` of the current enumerable minus 1 to the current enumerable (i.e. the last member of an array)

### Child operator

Syntax: `child` or `[child]` or `['child']`

Child operators match on an index, key, member, or property of the enumerable. In its non-normalized form a child operator is preceded by `.` or wrapped in '[]'. In bracket notation the child may optionally be wrapped in single quotes. Enumpath will attempt to resolve the data type of the child operator in the following order of precedence:

1. as an integer key or index (if the segment is integer-like),
2. then as a string key,
3. then as a symbol key,
4. and finally as a public property (i.e. a public method of the target that expects no arguments)

#### Examples

```
Car = Struct.new(:color, :transmition, :owners)
hiundai = Car.new('blue', :automatic, [{ name: 'Bill' }, { name: 'Ted' }])
subaru = Car.new('gold', :standard, [{ name: 'Kate' }])
jeep = Car.new('black', :automatic, [])
garages = [{ 'cars' => [hiundai, subaru] }, { 'cars' => [jeep] }]
Enumpath.apply('1', garages) # => [{"cars"=>[#<struct Car color="black", transmition=:automatic, owners=[]>]}]
Enumpath.apply('0.cars.-1', garages) # => [#<struct Car color="gold", transmition=:standard, owners=[{:name=>"Kate"}]>]
Enumpath.apply('1.cars.0.owners.length', garages) # => [0]
```

### Wildcard operator

Syntax: `*` or `[*]`

Wildcards match each immediate member of the enumerable.

### Recursive descent operator

Syntax: `..`

Applies the remaining path expression segments recursively to all members of the enumerable regardless of their nesting level, including the enumerable itself.

### Slice operator

Syntax: `[start:end:step]`, `[start:]`, `[start:end]`, `[start::step]`, `[:end]`, `[:end:step]`, `[::step]`, ...

The slice operator selects a range of elements like Ruby's _`start...end`_ literal, excluding the end value, and then selects each _step_ items. The _start_, _end_, and _step_ arguments default to `0`, `Enumerable#length`, and `1` respectively. The remaining path expression segments are passed to each member whose index is included by the slice operator.

The operator accepts a mixed bag of argument combinations. For instance, these are all valid slice operators:

- `[1:8]`: passes through the members of the enumerable at indices 1 – 7
- `[1:]`: passes through the members of the enumerable at indices 1 – `Enumerable#length`
- `[:8]`: passes through the members of the enumerable at indices 0 – 7
- `[:8:2]`: passes through the members of the enumerable at indices 0, 2, 4, and 6
- `[::2]`: passes through the members of the enumerable at indices 0, 2, 4, 6, 8, ... up to `Enumerable#length`

### Union operator

Syntax: `[child1,child2,...]`

The union operator combines the results of two or more child operators. There is no limit to the number of child operators you can specify in a single union. Each child operator is separated by a comma (`,`). White space is stripped from around each child operator. Child operators can optionally be wrapped in single quotes. Bracket notation is not supporter in this context.

The following are all valid union operators:

- `[first,last]`
- `[first,middle,last]`
- `['first', middle , last]`

### Filter expression operator

Syntax: `[?(expression)]`, `[?(expression && expression)]`, `[?(expression || expression)]`, ...

A filter expression is made up of one or more boolean expressions. Each boolean expression consists of a child operator (`@.child` or `child`; the leading `@.` is optional), plus an optional pair of comparison operator and operand. The comparison operator can be any one of `==`, `!=`, `>=`, `<=`, `<=>`, `>`, `<`, `=~`, `!~`. The operand can be a string (`'some string'`), symbol (`:some_symbol`), boolean constant (`true` or `false`), nil constant (`nil`), regular expression (`/^Some\s+/i`), or numeric value (`10` or `1.0`). If an operator and operand are not included in an expression then the value located at the child operator is evaluated for truthiness. Multiple expression groups can be chained together with `&&` or `||` logical operators, but note that parenthetical grouping of expressions is not supported; the results of each are applied to the previous running result in order. Any member of the current enumerable that passes the net result of the filter expression will be included in further processing of the path.

The following are all valid filter expressions:

- `[?(@.isbn)]`: any member who has an `isbn` value that is not falsey
- `[?(isbn)]`: equivalent to the previous example
- `[?(@.price == 8)]`: any member whose `price` value is equal to 8
- `[?(@.price == 8 || @.price == 10)]`: members with a `price` of 8 _or_ 10
- `[?(@.price > 2 && @.price < 10)]`: members with a `price` greater than 8 _and_ less than 10
- `[?(@.name =~ /bob/i || @.name == 'Mark')]`: any member whose `name` matches the regex `/bob/i` or equals `'Mark'`

> Regular expression operands are safely parsed using the `to_regexp` gem

### Subscript expression operator

Syntax: `[(expression)]`

A subscript expression is made up of a singe expression that consists of a child operator (`@.child` or `child`; the leading `@.` is optional), plus an optional pair of arithmetic operator and operand. The arithmetic operator can be any one of `+`, `-`, `**`, `*`, `/`, or `%`. The operand can be a string (`'some string'`), symbol (`:some_symbol`), or numeric value (`10` or `1.0`). The expression is evaluated and the result becomes the subscript. If an operator and operand are not included in an expression then the value located at the child operator is used as the subscript. If the subscript represents a valid child path for the enumerable, the value of that member will be passed along for further processing of the path.

The following are all valid filter expressions:

- `[(@.length - 1)]`: the subscript becomes the length of the current enumerable, minus 1
- `[(length / 2)]`: the subscript becomes the index at half the length of the enumerable
- `[(@.type)]`: the subscript becomes the value at the `type` key, member, or property of the enumerable

## Examples

Given the same store example from the JSONPath project:

```ruby
store_info = {
  store: {
    book: [
      { category: "reference",
        author: "Nigel Rees",
        title: "Sayings of the Century",
        price: 8.95 },
      { category: "fiction",
        author: "Evelyn Waugh",
        title: "Sword of Honour",
        price: 12.99 },
      { category: "fiction",
        author: "Herman Melville",
        title: "Moby Dick",
        isbn: "0-553-21311-3",
        price: 8.99 },
      { category: "fiction",
        author: "J. R. R. Tolkien",
        title: "The Lord of the Rings",
        isbn: "0-395-19395-8",
        price: 22.99 }
    ],
    bicycle: { color: "red", price: 19.95 }
  }
}

# The authors of all the books in the store
Enumpath.apply("$.store.book[*].author", store_info)
# => ["Nigel Rees", "Evelyn Waugh", "Herman Melville", "J. R. R. Tolkien"]

# All prices in the store
Enumpath.apply("$..price", store_info)
# => [8.95, 12.99, 8.99, 22.99, 19.95]

# All things in store, which are some books and a red bicycle
Enumpath.apply("$.store.*", store_info)
# => [[{:category=>"reference",
#       :author=>"Nigel Rees",
#       :title=>"Sayings of the Century",
#       :price=>8.95},
#      {:category=>"fiction",
#       :author=>"Evelyn Waugh",
#       :title=>"Sword of Honour",
#       :price=>12.99},
#      {:category=>"fiction",
#       :author=>"Herman Melville",
#       :title=>"Moby Dick",
#       :isbn=>"0-553-21311-3",
#       :price=>8.99},
#      {:category=>"fiction",
#       :author=>"J. R. R. Tolkien",
#       :title=>"The Lord of the Rings",
#       :isbn=>"0-395-19395-8",
#       :price=>22.99}],
#     {:color=>"red", :price=>19.95}]

# The third book
Enumpath.apply("$..book[2]", store_info)
# => [{:category=>"fiction", :author=>"Herman Melville", :title=>"Moby Dick", :isbn=>"0-553-21311-3", :price=>8.99}]

# The last book in order
Enumpath.apply("$..book[(@.length-1)]", store_info)
Enumpath.apply("$..book[-1:]", store_info)
# => Both return: [{:category=>"fiction", :author=>"J. R. R. Tolkien", :title=>"The Lord of the Rings", :isbn=>"0-395-19395-8", :price=>22.99}]

# The first two books in order. Both of these path expressions are equivalent
Enumpath.apply("$..book[0,1]", store_info)
Enumpath.apply("$..book[:2]", store_info)
# => [{:category=>"reference",
#      :author=>"Nigel Rees",
#      :title=>"Sayings of the Century",
#      :price=>8.95},
#     {:category=>"fiction",
#      :author=>"Evelyn Waugh",
#      :title=>"Sword of Honour",
#      :price=>12.99}]

# All books with an isbn number
Enumpath.apply("$..book[?(@.isbn)]", store_info)
# => [{:category=>"fiction",
#      :author=>"Herman Melville",
#      :title=>"Moby Dick",
#      :isbn=>"0-553-21311-3",
#      :price=>8.99},
#     {:category=>"fiction",
#      :author=>"J. R. R. Tolkien",
#      :title=>"The Lord of the Rings",
#      :isbn=>"0-395-19395-8",
#      :price=>22.99}]

# All books with a price less than 10
Enumpath.apply("$..book[?(@.price<10)]", store_info)
# => [{:category=>"reference",
#      :author=>"Nigel Rees",
#      :title=>"Sayings of the Century",
#      :price=>8.95},
#     {:category=>"fiction",
#      :author=>"Herman Melville",
#      :title=>"Moby Dick",
#      :isbn=>"0-553-21311-3",
#      :price=>8.99}]

# All members of the enumerable, recursively
Enumpath.apply("$..*", store_info)
# => [{:book=>
#       [{:category=>"reference",
#         :author=>"Nigel Rees",
#         :title=>"Sayings of the Century",
#         :price=>8.95},
#        {:category=>"fiction",
#         :author=>"Evelyn Waugh",
#         :title=>"Sword of Honour",
#         :price=>12.99},
#        {:category=>"fiction",
#         :author=>"Herman Melville",
#         :title=>"Moby Dick",
#         :isbn=>"0-553-21311-3",
#         :price=>8.99},
#        {:category=>"fiction",
#         :author=>"J. R. R. Tolkien",
#         :title=>"The Lord of the Rings",
#         :isbn=>"0-395-19395-8",
#         :price=>22.99}],
#      :bicycle=>{:color=>"red", :price=>19.95}},
#     [{:category=>"reference",
#       :author=>"Nigel Rees",
#       :title=>"Sayings of the Century",
#       :price=>8.95},
#      {:category=>"fiction",
#       :author=>"Evelyn Waugh",
#       :title=>"Sword of Honour",
#       :price=>12.99},
#      {:category=>"fiction",
#       :author=>"Herman Melville",
#       :title=>"Moby Dick",
#       :isbn=>"0-553-21311-3",
#       :price=>8.99},
#      {:category=>"fiction",
#       :author=>"J. R. R. Tolkien",
#       :title=>"The Lord of the Rings",
#       :isbn=>"0-395-19395-8",
#       :price=>22.99}],
#     {:color=>"red", :price=>19.95},
#     {:category=>"reference",
#      :author=>"Nigel Rees",
#      :title=>"Sayings of the Century",
#      :price=>8.95},
#     {:category=>"fiction",
#      :author=>"Evelyn Waugh",
#      :title=>"Sword of Honour",
#      :price=>12.99},
#     {:category=>"fiction",
#      :author=>"Herman Melville",
#      :title=>"Moby Dick",
#      :isbn=>"0-553-21311-3",
#      :price=>8.99},
#     {:category=>"fiction",
#      :author=>"J. R. R. Tolkien",
#      :title=>"The Lord of the Rings",
#      :isbn=>"0-395-19395-8",
#      :price=>22.99},
#     "reference",
#     "Nigel Rees",
#     "Sayings of the Century",
#     8.95,
#     "fiction",
#     "Evelyn Waugh",
#     "Sword of Honour",
#     12.99,
#     "fiction",
#     "Herman Melville",
#     "Moby Dick",
#     "0-553-21311-3",
#     8.99,
#     "fiction",
#     "J. R. R. Tolkien",
#     "The Lord of the Rings",
#     "0-395-19395-8",
#     22.99,
#     "red",
#     19.95]
```

## Options

### :return_type

By default, Enumpath returns the values that match the path expression. Like the original JSONPath implementation, Enumpath also supports returning path results instead of values. This can be useful for collecting static paths from dynamic paths.

```ruby
party = { food: %w[pizza tacos] }
Enumpath.apply("food.*", party, result_type: :path) # => ["$['food'][0]", "$['food'][1]"]
```

Each returned path is a valid path expression that can be used in calls to `Enumpath.apply`. If you want to be explicit about returning values instead of paths you can specify that with the option `result_type: :value`.

### :verbose

Seeing how your path expression is being applied to an enumerable can be helpful in understanding the path expression syntax. Enumpath has a built-in logger to assist with this. It can be enabled by simply passing `verbose: true` as an option on `Enumpath.apply`. By default this will log debugging information to STDOUT, however you can provide your own logger.

For example:

```ruby
Enumpath.logger.logger = ::Logger.new('log/enumpath.log')
```

Once enabled, it will log debugging information like so:

```
Enumpath.apply('$.store.book', store_info, verbose: true)

--------------------------------------
Enumpath: Path normalized
--------------------------------------
original  : $.store.book
normalized: ["store", "book"]
--------------------------------------
Enumpath: Applying
--------------------------------------
operator: ["store", "book"]
to      : {:store=>{:book=>[{:category=>"reference", :author...
--------------------------------------
Enumpath: Child operator detected
  --------------------------------------
  Enumpath: Applying
  --------------------------------------
  operator: ["book"]
  to      : {:book=>[{:category=>"reference", :author=>"Nigel ...
  --------------------------------------
  Enumpath: Child operator detected
    --------------------------------------
    Enumpath: Storing
    --------------------------------------
    resolved_path: ["store", "book"]
    enum        : [{:category=>"reference", :author=>"Nigel Rees", :...
    --------------------------------------
    Enumpath: New Result
    --------------------------------------
    result: [{:category=>"reference", :author=>"Nigel Rees", :...
```

You can also control verbose mode via `Enumpath.verbose = true` and `Enumpath.verbose = false`.

## Path normalization

When you give a string path to Enumpath it will automatically normalize it to an array of path segments. You can also pass it an array of path segments to avoid the normalization, for instance if the normalization process is having trouble parsing your path, or you happen to have a pre-normalized path already. For example the path `['pets']..[?(@.age > 10)].name` is represented in normalized form as `['pets', '..', '?(@.age > 10)', 'name']`. For the most part you should stick with string paths and let Enumpath normalize on its own.

### Normalized path caching

To save a little bit of time on consecutive calls Enumpath caches the normalized version of each path. This is an implementation detail that can generally be ignored but if you run into trouble with it you can clear the cache with `Enumpath.path_cache.reset`.

## Deviations from the Original JSONPath Spec

1. The JSONPath spec required that `false` be returned when no matches were found, but Enumpath will return an empty result set (`[]`) instead. This is a thoughtful divergence based on the principle of least astonishment and the robustness principle.

2. Enumpath supports relative child indexes, which the original implementation did not support. For instance:

        # Get the last element. Both are equivalent to `$..book[-1:]`
        Enumpath.apply('$..book.-1', store_info)
        Enumpath.apply('$..book[-1]', store_info)

3. The original implementations of JSONPath allowed unchecked evaluation of filter and subscript expressions. Enumpath limits those expressions to a reasonable subset of operations as detailed in the [Operator Reference](#operator-reference) section and uses `public_send` rather than `eval` to resolve expressions as necessary.

4. The original JSONPath spec did not include support for using logical operators to chain expressions in filter expression operators. This addition was inspired by [Gergely Brautigam's](https://skarlso.github.io/2017/05/28/replace-eval-with-object-send-and-a-parser/) work on [joshbuddy/jsonpath](https://github.com/joshbuddy/jsonpath)

## Requirements

Enumpath requires Ruby 2.3.0 or higher.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/youearnedit/enumpath](). Please read [CONTRIBUTING.md]() for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags](https://github.com/youearnedit/enumpath/tags) on this repository.

## Authors

- [Chris Bloom](https://github.com/chrisbloom7) - YouEarnedIt

See also the list of [contributors](https://github.com/youearnedit/enumpath/graphs/contributors) who participated in this project.

## License

Copyright 2018 YouEarnedIt.com

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

[www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

## Acknowledgements

This project is maintained by the Engineering team at [YouEarnedIt](http://youearnedit.com), an employee engagement and performance metrics platform, headquartered in Austin, TX.

Enumpath is based on [Stefan Goessner's JSONPath spec][jsonpath], and was inspired by several similar libraries:

- [nickcharlton/keypath-ruby](https://github.com/nickcharlton/keypath-ruby)
- [joshbuddy/jsonpath](https://github.com/joshbuddy/jsonpath)

[jsonpath]: http://goessner.net/articles/JsonPath/
[ci-image]: https://circleci.com/gh/youearnedit/enumpath.svg?style=svg
[ci]: https://circleci.com/gh/youearnedit/enumpath
[version-image]: https://badge.fury.io/rb/enumpath.svg
[version]: https://badge.fury.io/rb/enumpath
[hound-badge-image]: https://img.shields.io/badge/Reviewed_by-Hound-8E64B0.svg
[hound]: https://houndci.com
