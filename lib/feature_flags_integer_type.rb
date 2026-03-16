# frozen_string_literal: true

# Stores feature flags bitmask in a decimal column (to support >63 bits) but casts to Integer
# for in-app use (Flag Shih Tzu bitwise operations). Avoids ActiveModel::RangeError when
# the bitmask exceeds 2^63 - 1.
class FeatureFlagsIntegerType < ActiveModel::Type::Value
  def type
    :integer
  end

  def serialize(value)
    return nil if value.nil?

    value.to_s
  end

  private

  def cast_value(value)
    return 0 if value.blank?

    value.to_i
  end
end
