# == Schema Information
#
# Table name: supported_languages
#
#  id          :bigint           not null, primary key
#  code        :string(10)       not null
#  name        :string(100)      not null
#  native_name :string(100)      not null
#  enabled     :boolean          default(TRUE), not null
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_supported_languages_on_code     (code) UNIQUE
#  index_supported_languages_on_enabled  (enabled)
#

class SupportedLanguage < ApplicationRecord
  validates :code, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :native_name, presence: true, length: { maximum: 100 }
  validates :enabled, inclusion: { in: [true, false] }

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :by_code, ->(code) { where(code: code) }

  # Class methods for common operations
  def self.enabled_codes
    enabled.pluck(:code)
  end

  def self.enabled_options
    enabled.pluck(:name, :code)
  end

  def self.enabled_options_with_native
    enabled.pluck(:native_name, :code)
  end

  def self.find_by_code(code)
    find_by(code: code)
  end

  def self.normalize_code(code)
    # Convert hyphens to underscores for consistency
    code.to_s.tr('-', '_')
  end

  def self.find_by_normalized_code(code)
    normalized = normalize_code(code)
    find_by(code: normalized) || find_by(code: code)
  end

  # Instance methods
  def display_name
    "#{native_name} (#{name})"
  end

  def to_s
    display_name
  end
end
