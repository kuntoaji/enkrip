require 'minitest/autorun'

ENV['ENKRIP_LENGTH'] = '32'
ENV['ENKRIP_SALT']   = 'y\xBC\xAD\xA7\xAE6\xAD\x9F](\x89\xB2\xF6!\xED\xC8\xA2(1\x8E\xA9&/ef`\xD3\xB3\x11\xB6C\xB4' # SecureRandom.random_bytes(LENGTH)
ENV['ENKRIP_SECRET'] = 'f031fbebc6bb5a69094139c24090fd42'

require_relative '../lib/enkrip'

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:', encoding: 'unicode'
ActiveRecord::Base.connection.create_table(:example_models, force: true) do |t|
  t.text :my_string
  t.text :my_numeric
end

class ExampleModel < ActiveRecord::Base
  include Enkrip::Model
  validates :my_numeric, numericality: { greater_than: 0 }
  validates :my_string, presence: true

  enkrip_configure do |config|
    config.string_attributes << :my_string
    config.numeric_attributes << :my_numeric
    config.purpose = :example # optional
  end
end
