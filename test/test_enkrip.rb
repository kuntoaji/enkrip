require 'test_helper'

describe Enkrip do
  def test_version
    assert Enkrip::VERSION
  end

  def test_encryption_decryption
    model = ExampleModel.new my_string: '', my_numeric: 0
    assert_equal model.valid?, false

    model.my_string = 'my example string'
    model.my_numeric = 1
    model.save!
    model.reload

    raw = ActiveRecord::Base.connection.exec_query 'SELECT my_string, my_numeric FROM example_models limit 1'
    encrypted_my_string = raw.rows.first.first
    encrypted_my_numeric = raw.rows.first.last

    assert_equal encrypted_my_string.nil?, false
    assert_equal encrypted_my_string.empty?, false
    refute_equal encrypted_my_string, model.my_string
    assert_equal model.my_string, 'my example string'
    assert_equal Enkrip::Engine.decrypt(encrypted_my_string, purpose: :example), 'my example string'

    assert_equal encrypted_my_numeric.nil?, false
    assert_equal encrypted_my_numeric.empty?, false
    refute_equal encrypted_my_numeric, model.my_numeric
    assert_equal model.my_numeric, 1
    assert_equal Enkrip::Engine.decrypt(encrypted_my_numeric, purpose: :example).to_i, 1
  end
end
