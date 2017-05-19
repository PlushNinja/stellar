#encoding: utf-8

class Page < ActiveRecord::Base

  # Pages must be aware of their routes since they may link to anything.
  include Rails.application.routes.url_helpers

  resourcify
  include Authority::Abilities
  include Imageable
  include FriendlyId
  friendly_id :slugger, use: [:slugged, :history]
  acts_as_nested_set scope: :store,
                     dependent: :nullify,
                     counter_cache: :children_count

  #---
  enum purpose: {
    route: 0,           # navigation node routed to #slug
    primary: 1,         # page with content sections
    secondary: 2,       # secondary content (deprecated)
    banner: 3,          # banner container (deprecated)
    template: 4,        # printed page template
    category_menu: 6,   # menu from linked category (or root if nil)
    product_link: 7,    # link to product
    promotion_link: 8,  # link to promotion
    header: 10,         # virtual page containing main navigation
    footer: 11,         # virtual page containing footer links
    navigation: 12,     # secondary navigation
  }

  PRESENTATION = {
    'route' => {icon: '', appearance: 'danger'},
    'primary' => {icon: 'file-text-o', appearance: 'success'},
    'secondary' => {icon: 'file-text-o', appearance: 'success'},
    'banner' => {icon: ''},
    'template' => {icon: 'file-o', appearance: 'warning'},
    'category_menu' => {icon: 'sitemap', appearance: 'info'},
    'product_link' => {icon: 'cube', appearance: 'info'},
    'promotion_link' => {icon: 'tag', appearance: 'info'},
    'header' => {icon: 'navicon'},
    'footer' => {icon: 'paragraph'},
    'navigation' => {icon: 'share-alt'}
  }.freeze

  #---
  belongs_to :store

  # Resource is anything the page may refer to, depending on its purpose.
  belongs_to :resource, polymorphic: true

  has_and_belongs_to_many :albums

  #---
  validates :title, presence: true
  validates :resource, presence: true,
    if: -> (page) { page.product_link? },
    on: :update

  #---
  # Finds the first page that returns a non-nil path.
  def self.entry_point
    find { |page| page.path }
  end

  def self.available_purposes
    purposes.slice(
      :route, :primary, :template,
      :category_menu, :product_link, :promotion_link,
      :navigation
    )
  end

  def self.purpose_options
    available_purposes.keys.map { |p| [Page.human_attribute_value(:purpose, p), p] }
  end

  #---
  def can_have_children?
    header? || footer? || navigation?
  end

  def can_have_content?
    primary? || template?
  end

  def movable?
    route? || primary? || navigation? || category_menu? || product_link? || promotion_link?
  end

  def can_have_albums?
    primary?
  end

  def slugger
    [:title, [:title, -> { store.name }]]
  end

  # Prevent FriendlyId from changing slugs on route pages.
  def should_generate_new_friendly_id?
    !route? && title_changed? || super
  end

  def to_s
    return human_attribute_value(:purpose) if header? || footer?
    title
  end

  def icon
    Page::PRESENTATION[purpose][:icon]
  end

  def appearance
    Page::PRESENTATION[purpose][:appearance]
  end

  def description
    content
  end

  # Navigation pages and category menu pages contain items.
  def contained_items
    case
    when navigation?
      children
    when category_menu? && resource.present?
      if resource.leaf?
        resource.products.visible.sorted(resource.product_scope)
      else
        resource.children.visible
      end
    else nil
    end
  end

  # Pages are rendered with partials corresponding to purpose.
  def to_partial_path
    "pages/#{purpose}"
  end

  # Path to partials to render the contained items of a category menu.
  # In most cases the items are categories, but for leaf categories,
  # products are rendered.
  def contained_item_partial_path
    return 'products' if resource.present? && resource.leaf?
    'categories'
  end

  # Path to a page object depends on its purpose. Route and primary pages
  # use plain page routes, product link pages point to the target product.
  # Navigation pages point to their first child, category menu pages point
  # to their target, or first child if target is nil.
  def path
    case
    when route? || primary?
      show_page_path(self)
    when product_link?
      show_product_path(resource.category, resource)
    when promotion_link?
      show_promotion_path(resource)
    when navigation?
      children.first.path
    when category_menu?
      category = resource || store.first_category
      category.present? ? show_category_path(category) : nil
    else nil
    end
  end
end
