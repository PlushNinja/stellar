#encoding: utf-8
#
# Sections are page subdivisions defining the layout of its content segments.
# The segments contain the actual content and have optional associations to
# external resources like images, products, promotions, etc.
#
# The layout for a section is selected from presets that specify how many
# contained segments are created.
#
class Section < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Pictureable
  include Reorderable

  #---
  # Presets as layout, name, column count tuples.
  PRESETS = [
    [
      ['twelve', '12', 1],
      ['eight-four', '8+4', 2],
      ['four-eight', '4+8', 2],
      ['four-four-four', '4+4+4', 3],
      ['two-two-two-two-two-two', '2+2+2+2+2+2', 6],
    ],
    [
      ['six-six', '6+6', 2],
      ['nine-three', '9+3', 2],
      ['three-nine', '3+9', 2],
      ['six-three-three', '6+3+3', 3],
      ['three-six-three', '3+6+3', 3],
      ['three-three-six', '3+3+6', 3],
      ['three-three-three-three', '3+3+3+3', 4],
    ]
  ].freeze

  # Available content widths defined in layouts.css.
  WIDTHS = %w{
    spread col-12 col-10 col-8 col-6
  }.freeze

  #---
  belongs_to :page, touch: true, required: true
  has_many :columns, dependent: :destroy
  has_many :segments, through: :columns

  default_scope { sorted }
  scope :named, -> { where.not(name: nil) }

  #---
  validates :name, uniqueness: {scope: :page, allow_blank: true}
  validates :width, inclusion: {in: WIDTHS}

  #---
  def self.preset_menu_options
    PRESETS
  end

  def self.width_options
    WIDTHS.map { |w| [Section.human_attribute_value(:width, w), w] }
  end

  #---
  def spread?
    width == 'spread'
  end

  def gutter
    gutters? ? 'gutters' : 'no-gutters'
  end

  def layout_options
    PRESETS.flatten(1).map { |l| [l[1], l[0]] }
  end

  def picture_options
    {purpose: ['presentational']}
  end

  def background_picture
    cover_picture
  end

  def to_s
    name || priority + 1
  end
end
