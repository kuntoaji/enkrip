# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Enkrip is a Ruby gem that encrypts and decrypts Active Record model attributes with `ActiveSupport::MessageEncryptor`. Supported Active Record versions: `>= 5.2, < 6` (see `enkrip.gemspec`).

## Commands

- Install dependencies: `bundle install`
- Run all tests (default Rake task): `bundle exec rake` or `bundle exec rake test`
- Run one test file: `bundle exec ruby -Itest test/test_enkrip.rb`
- Run one test method: `bundle exec ruby -Itest test/test_enkrip.rb -n test_encryption_decryption`
- Build the gem: `gem build enkrip.gemspec`

The dependency pins are old (`Gemfile.lock` was bundled with Bundler 1.16.6; gemspec pins `activerecord < 6`, `bundler ~> 1.16`, `rake ~> 12.3`, `sqlite3 ~> 0`). On a modern Ruby (verified on 4.0.7), `bundle exec rake` fails with `Could not find gem 'sqlite3 (~> 0)'`. Use a Ruby version that matches these pins, or update the pins first.

There is no linter configured. `spec.files` uses `git ls-files`, so a new file must be tracked by git to ship in the gem.

## Architecture

- `lib/enkrip.rb` loads `active_record`, then `version`, `engine`, and `model`.
- `lib/enkrip/engine.rb` reads `ENKRIP_LENGTH`, `ENKRIP_SALT`, and `ENKRIP_SECRET` **at load time** and derives `Enkrip::KEY` with `ActiveSupport::KeyGenerator`. One class-level `MessageEncryptor` (`@@verifier`) backs `Enkrip::Engine.encrypt` / `.decrypt`, which both accept a `purpose:` keyword. A purpose mismatch makes `decrypt` return `nil`.
  - Consequence: set the env vars before you require `enkrip`. `test/test_helper.rb` does this, then builds an in-memory SQLite schema and an `ExampleModel`.
- `lib/enkrip/model.rb` is an `ActiveSupport::Concern`:
  - Callbacks: `before_save :encrypt`, then `after_save :decrypt` and `after_find :decrypt`. In-memory attribute values stay plaintext; only the stored column values are ciphertext. Blank values are not encrypted.
  - `enkrip_configure` yields an `OpenStruct` (`string_attributes`, `numeric_attributes`, `purpose`, `convert_method_for_numeric_attribute` default `:to_i`, `default_value_if_numeric_attribute_blank` default `0`) and stores it in the model constant `ENCRYPTED_CONFIG`. Call it once per model.
  - For each numeric attribute, it defines a reader override that calls `super`, forces UTF-8, and applies the convert method. Encrypted columns must be `text`, because numeric values are stored as ciphertext strings.

## Known limitations (from README)

- Not compatible with `activerecord-import`.
- Can conflict with `ActiveRecord::Attributes` in some cases.
- Numeric attributes are forced to UTF-8.

## Release notes

Record user-visible changes in `CHANGELOG.md` and bump `Enkrip::VERSION` in `lib/enkrip/version.rb`.
