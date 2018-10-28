# frozen_string_literal: true

module Enkrip
  LENGTH = ENV['ENKRIP_LENGTH'].to_i # ActiveSupport::MessageEncryptor.key_len
  SALT   = ENV['ENKRIP_SALT'] # SecureRandom.random_bytes(LENGTH)
  SECRET = ENV['ENKRIP_SECRET']
  KEY    = ActiveSupport::KeyGenerator.new(SECRET).generate_key(SALT, LENGTH).freeze

  class Engine
    class << self
      @@verifier = ActiveSupport::MessageEncryptor.new(Enkrip::KEY)

      def encrypt(value, purpose: nil)
        @@verifier.encrypt_and_sign value, purpose: purpose
      end

      def decrypt(value, purpose: nil)
        @@verifier.decrypt_and_verify value, purpose: purpose
      end
    end
  end
end
