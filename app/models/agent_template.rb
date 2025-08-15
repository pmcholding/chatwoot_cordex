# == Schema Information
#
# Table name: agent_templates
#
#  id           :bigint           not null, primary key
#  description  :text
#  instructions :text             not null
#  language     :string           default("en"), not null
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_agent_templates_on_language  (language)
#  index_agent_templates_on_name      (name)
#
class AgentTemplate < ApplicationRecord
  # Supported languages
  SUPPORTED_LANGUAGES = %w[en pt-BR es fr de it ja ko zh-CN zh-TW ar ru].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :instructions, presence: true
  validates :language, presence: true, inclusion: { in: SUPPORTED_LANGUAGES }

  scope :for_language, lambda { |language|
    # Try exact match first with the input language
    templates = where(language: language)

    # If no exact match, try converting between hyphen and underscore formats
    if templates.empty?
      # Convert pt-BR to pt_BR or vice versa
      alternative_format = if language.include?('-')
                             language.tr('-', '_')
                           else
                             language.tr('_', '-')
                           end

      templates = where(language: alternative_format)
    end

    # If no exact match and language is a base language (e.g., 'pt'), try with country code
    if templates.empty? && language.length == 2
      country_variants = where('language LIKE ? OR language LIKE ?', "#{language}-%", "#{language}_%")
      templates = country_variants if country_variants.any?
    end

    # If still no match, fallback to English
    templates = where(language: 'en') if templates.empty?

    templates
  }
  scope :by_name, -> { order(:name) }
end
