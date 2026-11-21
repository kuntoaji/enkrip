# Migrate from Enkrip to Active Record Encryption

This guide moves data that Enkrip encrypted to [Active Record Encryption](https://guides.rubyonrails.org/active_record_encryption.html), which is built into Rails 7.0 and newer. The guide was tested with Rails 8.1 against data that Enkrip wrote on Active Support 5.2.

Enkrip requires Active Record 5.2, so you cannot install it next to Rails 7. This guide uses a small decryptor that reads the old Enkrip values without the gem.

## Before you start

- Back up the database. Do a test run on a copy of production data first.
- Plan a maintenance window. Between the deploy and the end of the backfill, rows that are not migrated yet show the Enkrip ciphertext as a string, and numeric attributes show `0`. Stop writes to the affected tables during the window.
- Keep the `ENKRIP_LENGTH`, `ENKRIP_SALT`, and `ENKRIP_SECRET` values until the migration is complete.

## Step 1: Remove Enkrip and upgrade Rails

1. Remove `gem 'enkrip'` from the Gemfile.
2. Upgrade the app to Rails 7.0 or newer.

## Step 2: Set up Active Record Encryption keys

Generate the keys:

```bash
bin/rails db:encryption:init
```

Store the output in Rails credentials (`bin/rails credentials:edit`) or in a secrets manager. Do not store the keys in plaintext environment files.

## Step 3: Add the legacy decryptor

Create `lib/enkrip_legacy.rb`:

```ruby
# frozen_string_literal: true

# Decrypts values that the enkrip gem wrote. Delete this file after the migration.
module EnkripLegacy
  class Error < StandardError; end

  # Enkrip used ActiveSupport::MessageEncryptor with default options. The default
  # cipher was AES-256-GCM in a Rails 5.2 app (load_defaults 5.2) and AES-256-CBC
  # otherwise. Pin every option, because the defaults changed in later Rails versions.
  # Marshal is safe here only because the encryptor checks the message signature first.
  def self.encryptors
    @encryptors ||= begin
      key = ActiveSupport::KeyGenerator.new(
        ENV.fetch("ENKRIP_SECRET"),
        hash_digest_class: OpenSSL::Digest::SHA1,
        iterations: 2**16
      ).generate_key(ENV.fetch("ENKRIP_SALT"), ENV.fetch("ENKRIP_LENGTH").to_i)

      [
        ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: Marshal),
        ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-cbc", digest: "SHA1", serializer: Marshal)
      ]
    end
  end

  # Raises EnkripLegacy::Error when no encryptor can read the value. Enkrip
  # returned nil on a purpose mismatch; this method raises instead, so a wrong
  # purpose cannot overwrite data with nil.
  def self.decrypt(value, purpose: nil)
    encryptors.each do |encryptor|
      result = encryptor.decrypt_and_verify(value, purpose: purpose)
      return result unless result.nil?
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      next
    end
    raise Error, "cannot decrypt the Enkrip value (check the ENKRIP_* variables and the purpose)"
  end
end
```

Load it from the rake task in Step 6, or add `require "enkrip_legacy"` to an initializer.

## Step 4: Update the models

Replace `include Enkrip::Model` and the `enkrip_configure` block with `encrypts`. Keep the columns as `text`.

Before:

```ruby
class Post < ActiveRecord::Base
  include Enkrip::Model

  enkrip_configure do |config|
    config.string_attributes << :my_string
    config.numeric_attributes << :my_numeric
    config.purpose = :example
  end
end
```

After:

```ruby
class Post < ApplicationRecord
  attribute :my_numeric, :integer
  encrypts :my_string, :my_numeric
end
```

How the Enkrip options map:

| Enkrip option | Active Record Encryption |
| --- | --- |
| `string_attributes` | `encrypts :name` |
| `numeric_attributes` | `attribute :name, :integer` before `encrypts :name`. Use `:float` or `:decimal` if `convert_method_for_numeric_attribute` was `:to_f` or `:to_d`. |
| `purpose` | Used only by the backfill in Step 6. |
| `default_value_if_numeric_attribute_blank` | No equivalent. A blank numeric value is now `nil`, not `0`. |

To query an encrypted column with `where`, add `deterministic: true` to that attribute. Enkrip could not query encrypted columns, so existing code does not need this.

## Step 5: Allow unencrypted reads during the migration

Add this line to `config/application.rb`:

```ruby
config.active_record.encryption.support_unencrypted_data = true
```

Without this setting, every read of a row that is not migrated yet raises `ActiveRecord::Encryption::Errors::Decryption`. You remove the setting in Step 8.

## Step 6: Run the backfill

Create `lib/tasks/enkrip.rake`. Edit `enkrip_targets` so that it lists every model that used Enkrip.

```ruby
# frozen_string_literal: true

# Moves Enkrip data to Active Record Encryption. Delete this file after the migration.
require "enkrip_legacy"

# One entry per model. Copy the attributes and the purpose from the model's old
# enkrip_configure block. Use purpose: nil if the block did not set one.
enkrip_targets = lambda do
  {
    Post => { attributes: %i[my_string my_numeric], purpose: :example }
  }
end

namespace :enkrip do
  desc "Re-encrypt Enkrip values with Active Record Encryption"
  task migrate: :environment do
    enkrip_targets.call.each do |model, config|
      model.find_each do |record|
        values = config[:attributes].each_with_object({}) do |attr, result|
          raw = record.read_attribute_before_type_cast(attr)
          next if raw.nil? || ActiveRecord::Encryption.encryptor.encrypted?(raw)

          # Enkrip stored blank values as plaintext. Re-save them so they get encrypted.
          result[attr] = raw.blank? ? raw : EnkripLegacy.decrypt(raw, purpose: config[:purpose])
        end
        # update_columns skips validations, callbacks, and updated_at.
        record.update_columns(values) if values.any?
      end
    end
  end

  desc "Count rows that still hold values that are not encrypted by Active Record Encryption"
  task check: :environment do
    remaining = 0
    enkrip_targets.call.each do |model, config|
      count = model.find_each.count do |record|
        config[:attributes].any? do |attr|
          raw = record.read_attribute_before_type_cast(attr)
          !raw.nil? && !ActiveRecord::Encryption.encryptor.encrypted?(raw)
        end
      end
      puts "#{model.name}: #{count} rows left"
      remaining += count
    end
    abort "Migration is not complete" if remaining.positive?
  end
end
```

Run the backfill with the old Enkrip values in the environment:

```bash
ENKRIP_LENGTH=... ENKRIP_SALT=... ENKRIP_SECRET=... bin/rails enkrip:migrate
```

The task skips values that are already encrypted, so you can run it again after a failure. If it raises `EnkripLegacy::Error`, check the `ENKRIP_*` values and the `purpose` for that model.

## Step 7: Verify

```bash
bin/rails enkrip:check
```

Every model must show `0 rows left`. Then open a few records in the Rails console and compare the values with the values in the old app.

## Step 8: Clean up

1. Remove `support_unencrypted_data = true` from `config/application.rb`, and deploy.
2. Delete `lib/enkrip_legacy.rb` and `lib/tasks/enkrip.rake`.
3. Remove `ENKRIP_LENGTH`, `ENKRIP_SALT`, and `ENKRIP_SECRET` from every environment.
4. Database backups made before the migration still hold Enkrip ciphertext. Keep the old `ENKRIP_*` values in a secrets manager for as long as you keep those backups, then destroy the values.

## Behavior changes

- A blank numeric attribute is `nil`, not `0`. Handle `nil` in your code, or set a default value for new records (`attribute :my_numeric, :integer, default: 0`).
- A value that cannot be decrypted raises an error. Enkrip returned `nil`.
