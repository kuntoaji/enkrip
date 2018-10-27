require 'minitest/autorun'
require_relative '../lib/enkrip'

class EnkripTest < Minitest::Test
  def test_version
    assert_equal '0.0.0', Enkrip::VERSION
  end
end
