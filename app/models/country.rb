class Country < ApplicationRecord

  self.primary_key = 'code'

  default_scope { order(:name) }

  #---
  def self.default
    find_by(code: I18n.default_locale.upcase)
  end

  #---
  def to_s
    name
  end
end
