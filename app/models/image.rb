#encoding: utf-8

class Image < ActiveRecord::Base

  include Reorderable

  belongs_to :imageable, polymorphic: true
  belongs_to :image_type
  has_attached_file :attachment,
    styles: {
      lightbox: '1000x1000>',
      presentational: '1000x1000>',
      technical: '400x400>',
      matchbox: '200x200>',
      thumbnail: '75x75>',
      icon: '25x25#',
    },
    convert_options: {
      lightbox: '-strip',
      presentational: '-strip',
      technical: '-strip',
      matchbox: '-strip -quality 75',
      thumbnail: '-strip -quality 70',
      icon: '-strip -quality 70',
    }
  before_post_process :resize_bitmaps
  before_create :assign_image_type

  scope :by_type, -> (type) { joins(:image_type).where(image_types: {name: type}) }

  delegate :url, to: :attachment

  validates_attachment :attachment,
    content_type: {
      content_type: [
        %r{\Aimage/(bmp|jpeg|jpg|png|x-png)},
        %r{\Aapplication/(pdf|msword)},
        %r{\aapplication/vnd.openxmlformats},
      ]
    }

  # Applicable image types due to attachment bitmappiness.
  def applicable_image_types
    ImageType.where(bitmap: is_bitmap?)
  end

  # Assign first applicable image type.
  def assign_image_type
    self.image_type = applicable_image_types.first
  end

  def is_bitmap?
    !!(attachment_content_type =~ /\Aimage/)
  end

  private
    def resize_bitmaps
      return false unless is_bitmap?
    end
end
