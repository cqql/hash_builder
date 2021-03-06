# HashBuilder

This gem allows you to build hashes in a way, that is totally copied from
[json_builder](https://github.com/dewski/json_builder). I created this, because
json_builder does not allow extraction of partials, which I rely heavily on, to
keep my JSON generation DRY.

And while I was at it, I found it a good idea to increase the abstraction level
and build hashes instead of JSON because, this allows for easier manipulation of
the results, application in more different circumstances and you can generate
JSON and YAML with the well known `to_json` and `to_yaml` methods from it.

## Usage

```ruby
require "hash_builder"
require "json"
require "yaml"

hash = HashBuilder.build do
  url "https://github.com/CQQL"
  name "CQQL"
  age 21

  interests [:ruby, :clojure] do |n|
    name n
  end

  loves do
    example do
      code :yes
    end
  end
end
#=> {:url=>"https://github.com/CQQL", :name=>"CQQL", :age=>21, :interests=>[{:name=>:ruby}, {:name=>:clojure}], :loves=>{:example=>{:code=>:yes}}}

hash.to_json
#=> "{\"url\":\"https://github.com/CQQL\",\"name\":\"CQQL\",\"age\":21,\"interests\":[{\"name\":\"ruby\"},{\"name\":\"clojure\"}],\"loves\":{\"example\":{\"code\":\"yes\"}}}"

hash.to_yaml
#=> "---\n:url: https://github.com/CQQL\n:name: CQQL\n:age: 21\n:interests:\n- :name: :ruby\n- :name: :clojure\n:loves:\n  :example:\n    :code: :yes\n"
```

## Usage with rails

To use HashBuilder in a rails app, add the gem to your Gemfile.

```ruby
gem "hash_builder"
```

From then on HashBuilder will render `.json_builder` templates as
JSON. But there is a special case in that HashBuilder actually renders
partials as hashes instead of JSON strings so that you can use them to
create nested data structures instead of strings to use in templates.

```ruby
class HashController < ApplicationController
  def index
    @users = [
      { name: "CQQL", quote: "Emacs > Vim" },
      { name: "Joshua Bloch", quote: "The cleaner and nicer the program, the faster it's going to run. And if it doesn't, it'll be easy to make it fast." }
    ]
  end
end
```

```ruby
# hash/index.json_builder
num_users @users.size

users @users.map { |u| render partial: "user", locals: { user: u } }
```

```ruby
# hash/_user.json_builder
name user[:name]
name_length user[:name].size
quote user[:quote]
```

A request to `/hash/` returns the following JSON response

```json
{
  "num_users": 2,
  "users": [
    {
      "name": "CQQL",
      "name_length": 4,
      "quote": "Emacs > Vim"
    },
    {
      "name": "Joshua Bloch",
      "name_length": 12,
      "quote": "The cleaner and nicer the program, the faster it's going to run. And if it doesn't, it'll be easy to make it fast."
    }
  ]
}
```

In a rails view there is also a special syntax to create a top level array

```ruby
array @users do |user|
  name user[:name]
  quote user[:quote]
end
```

This results in

```json
[
  {
    "name": "CQQL",
    "quote": "Emacs > Vim"
  },
  {
    "name": "Joshua Bloch",
    "quote": "The cleaner and nicer the program, the faster it's going to run. And if it doesn't, it'll be easy to make it fast."
  }
]
```

## Performance

There is a [benchmark script](./benchmark.rb), that returns the
following results on my machine

```
$ ruby benchmark.rb
                                   user     system      total        real
HashBuilder                    0.650000   0.070000   0.720000 (  0.714533)
HashBuilder + JSON.generate    1.290000   0.060000   1.350000 (  1.352620)
HashBuilder + to_json          4.650000   0.070000   4.720000 (  4.716388)
JSONBuilder                    1.780000   0.090000   1.870000 (  1.872545)
```

For some reason transforming hashes to JSON with `to_json` is really slow.

## Tradeoffs

This is built with [exec_env](https://github.com/CQQL/exec_env), so
there is quite a lot of ruby magic going on under the hood. As long as
you only use lexical bingings in your block, you won't notice
anything.

```ruby
def render_user (user)
  HashBuilder.build do
    name user.name
  end
end
```

But your dynamic bindings will be lost, because the block is executed
in another context.

```ruby
class User
  attr_accessor :email

  def to_hash
    HashBuilder.build do
      # email accessor is not available here.
      email_address email # => Error
    end
  end
end
```

This can be fixed however by explicitly passing a scop.e

```ruby
class User
  attr_accessor :email

  def to_hash
    HashBuilder.build(scope: self) do
      # All is fine now.
      email_address email
    end
  end
end
```

But there is yet another problem. If you tried to set the hash key
`email`, you would receive an error because the line `email email`
would actually expand to `user.email(user.email)` if `user` is the
user object, because `user` responds to `email`. The quite ugly
workaround looks like this

```ruby
class User
  attr_accessor :email

  def to_hash
    HashBuilder.build(scope: self) do
      # Bypass scope and local variables
      xsend :email, email
    end
  end
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hash_builder'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install hash_builder
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
