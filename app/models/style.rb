class Style < ApplicationRecord

  VARIABLES = {
    body_bg: {type: :color},
    text_color: {type: :color},
    link_color: {type: :color},
    navbar_default_bg: {type: :color},
    navbar_default_color: {type: :color},
    navbar_default_link_color: {type: :color},
    navbar_default_link_hover_color: {type: :color},
    navbar_default_link_hover_bg: {type: :color},
    navbar_default_link_active_color: {type: :color},
    navbar_default_link_active_bg: {type: :color},
    navbar_inverse_bg: {type: :color},
    navbar_inverse_color: {type: :color},
    navbar_inverse_link_color: {type: :color},
    navbar_inverse_link_hover_color: {type: :color},
    navbar_inverse_link_hover_bg: {type: :color},
    navbar_inverse_link_active_color: {type: :color},
    navbar_inverse_link_active_bg: {type: :color},
    footer_bg: {type: :color},
    footer_color: {type: :color},
    brand_primary: {type: :color},
    brand_success: {type: :color},
    brand_info: {type: :color},
    brand_warning: {type: :color},
    brand_danger: {type: :color},
    font_family_base: {type: :text},
    font_size_base: {type: :text},
    line_height_base: {type: :text},
    headings_font_family: {type: :text},
    headings_font_weight: {type: :text},
    headings_line_height: {type: :text},
  }.freeze

  store :variables, accessors: VARIABLES.keys, coder: JSON

  resourcify
  include Authority::Abilities

  # Attached stylesheet compiled by StyleGenerator from the styles above.
  # See #stylesheet_source.
  has_attached_file :stylesheet, {
    url: '/system/:class/:attachment/:filename.css'
  }
  do_not_validate_attachment_file_type :stylesheet

  before_post_process -> { false }
  after_save :generate_stylesheet,
    if: -> (style) { style.saved_change_to_preamble? || style.saved_change_to_variables? }

  #---
  belongs_to :store

  #---
  def to_scss
    variables
      .reject { |_, v| v.blank? }
      .map { |k, v| "$%s: %s;\n" % [k.dasherize, v] }.join
  end

  def to_s
    I18n.l(created_at.to_date)
  end

  private
    def generate_stylesheet
      reload
      Styles::Generator.new(store.theme, self).compile
    end
end
