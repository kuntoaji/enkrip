# frozen_string_literal: true

module Enkrip
  module Model
    extend ActiveSupport::Concern

    included do
      after_find :decrypt
      before_save :encrypt
      after_save :decrypt

      def encrypt
        self.class::ENCRYPTED_CONFIG.all_attributes.each do |attr|
          self[attr] = Enkrip::Engine.encrypt(self[attr], purpose: self.class::ENCRYPTED_CONFIG.purpose) if respond_to?(attr) && self[attr].present?
        end
      end

      def decrypt
        self.class::ENCRYPTED_CONFIG.all_attributes.each do |attr|
          self[attr] = Enkrip::Engine.decrypt(self[attr], purpose: self.class::ENCRYPTED_CONFIG.purpose) if respond_to?(attr) && self[attr].present?
        end
      end
    end

    class_methods do
      def enkrip_configure
        config = OpenStruct.new(
          string_attributes: [],
          numeric_attributes: [],
          purpose: nil,
          convert_method_for_numeric_attribute: :to_i,
          default_value_if_numeric_attribute_blank: 0
        )

        yield config

        config.all_attributes = config.string_attributes + config.numeric_attributes
        const_set :ENCRYPTED_CONFIG, config

        config.numeric_attributes.each do |attr|
          define_method(attr) do
            value = super()
            value.present? ? value.force_encoding('UTF-8').send(config.convert_method_for_numeric_attribute) : config.default_value_if_numeric_attribute_blank
          end
        end
      end
    end
  end
end
