# Enkrip

Encrypt & decrypt Active Record's model attributes with [ActiveSupport::MessageEncryptor](https://api.rubyonrails.org/v5.2.1/classes/ActiveSupport/MessageEncryptor.html). See [Enkrip Example Rails Application](https://github.com/kuntoaji/enkrip_example) for demo.

## Goals

* Seamlessly encrypt and decrypt value for both string and numeric attribute
* Compatible with Active Model validation
* Automatically convert numeric attributes to desired format after decryption

## Limitations

* All attributes that are defined in `numeric_attributes` will be forced to use UTF-8 encoding
* Enkrip requires Active Record 5.2 or newer
* Does not compatible with [activerecord-import](https://rubygems.org/gems/activerecord-import)
* In some cases, does not compatible with [ActiveRecord::Attributes](https://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html)

## Installation

Add `enkrip` to your Rails app’s Gemfile and run bundle install:

```ruby
gem 'enkrip'
```

## Configuration

After installation, you need to define `ENKRIP_LENGTH`, `ENKRIP_SALT`, and `ENKRIP_SECRET` environment variables:

```bash
# example
export ENKRIP_LENGTH=32 # 32 is default value from ActiveSupport::MessageEncryptor.key_len
export ENKRIP_SALT=random_salt_with_length_32 # you can generate from SecureRandom.random_bytes(YOUR_ENKRIP_LENGTH)
export ENKRIP_SECRET=random_secret_with_length_32
```

## Usage

Use text data type for encrypted attributes

```ruby
# migration

class CreatePosts < ActiveRecord::Migration[5.2]
  def change
    create_table :posts do |t|
      t.text :my_string
      t.text :my_numeric

      t.timestamps
    end
  end
end
```

After run the migration, define you encrypted attributes

```ruby
# Active Record model

class Post < ActiveRecord::Base
  include Enkrip::Model

  enkrip_configure do |config|
    config.string_attributes << :my_string
    config.numeric_attributes << :my_numeric
    config.purpose = :example # optional, default is nil
    config.convert_method_for_numeric_attribute = :to_f # optional, default is to_i
    config.default_value_if_numeric_attribute_blank =  0.0 # optional, default is 0
  end

  validates :my_numeric, numericality: { greater_than: 0 }
  validates :my_string, presence: true
end
```

You can check encrypted value from rails console with raw query

```ruby
# Rails 5.2 console
post = Post.new => #<Post id: nil, my_string: nil, my_numeric: nil, created_at: nil, updated_at: nil>
post.valid? # => false
post.errors.full_messages # => ["My numeric must be greater than 0", "My string can't be blank"]

post.my_string = "aloha" # => "aloha"
post.my_numeric = 5 # => 5
post.save # => true

raw = ActiveRecord::Base.connection.exec_query 'SELECT my_string, my_numeric FROM posts limit 1'

raw.rows.first[raw.columns.find_index('my_string')]
# => "TUVQcnRBck5oYzMvRlRZUWR3Mzlzdz09LS1tZ09xNGNYbnkzdFc2d1duMEIrdUdBPT0=--ffae1f04753ca5c636915746a4c6fccf81897138"

raw.rows.first[raw.columns.find_index('my_numeric')]
# => "TkdSbURRNzVMbUF6MjF0bjI2ZEtmQT09LS1rRHhqQ2xpWGhYaHBoRlhCRnVZSmh3PT0=--74e45e6c96df78258a1731994a71a74c5047d655"

post.reload
post.my_string # => "aloha"
post.my_numeric # => 5
```

You can use `Enkrip::Engine.encrypt` and `Enkrip::Engine.decrypt` to encrypt and decrypt a value.

```ruby
my_string = 'hello world'

encrypted_my_string = Enkrip::Engine.encrypt my_string
# => "MzZ1M0RDSWdQQ0VaRVJXT3NBYlVTWExWVnVSbXNBeXRMSC9wYWdoeW5Ddz0tLVNVT2l6NDJCd1ZxbW1lYnl2eC9PakE9PQ==--c7436c403595c18fef802a51be29f73d5bb73f19"

Enkrip::Engine.decrypt encrypted_my_string
# => "hello world"

# you can pass purpose parameter, default purpose is nil.
second_string = 'hello world 2'
another_encrypted_my_string = Enkrip::Engine.encrypt second_string, purpose: :example_purpose

Enkrip::Engine.decrypt another_encrypted_my_string, purpose: :random_purpose # => nil
Enkrip::Engine.decrypt another_encrypted_my_string # => nil
Enkrip::Engine.decrypt another_encrypted_my_string, purpose: :example_purpose # => "hello world 2"


```

## License

Enkrip is released under the [MIT License](https://opensource.org/licenses/MIT).
