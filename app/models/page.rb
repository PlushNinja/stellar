class Page < ApplicationRecord

  store :metadata, accessors: [
    :url, :description, :always_expand, :dynamic_navbar
  ], coder: JSON

  resourcify
  include Authority::Abilities
  include Trackable
  include Pictureable
  include Pageable
  include FriendlyId
  friendly_id :slugger, use: [:slugged, :scoped], scope: :store
  acts_as_nested_set scope: :store,
                     dependent: :destroy,
                     counter_cache: :children_count

  #---
  enum purpose: {
    route: 0,           # navigation node routed to #slug
    primary: 1,         # page with content sections
    category: 2,        # category page with optional content
    category_order: 6,  # category order page with optional content
    product: 3,         # product page with optional content
    promotion: 4,       # promotion page with optional content
    department: 5,      # department page with optional content
    header: 10,         # container for main navigation
    footer: 11,         # container for footer links
    dropdown: 20,       # dropdown container for other pages
    megamenu: 21,       # megamenu container for other pages
    continuous: 22,     # single page container for other pages
    contentmenu: 23,    # megamenu with its own layout and content
    template: 30,       # printed page template
    portal: 40,         # page with content sections meant for portals
    proxy: 41,          # proxy to a portal page for portal navigation
    external: 42,       # link to an external page (url)
    internal: 43,       # link to an internal page
  }

  PURPOSE_CHAIN = {
    category: [:category, :category_order],
    category_order: [:category_order, :category],
    dropdown: [:dropdown, :megamenu],
    megamenu: [:megamenu, :dropdown],
  }.freeze

  PRESENTATION = {
    'route' => {icon: 'share-alt', appearance: 'danger'},
    'primary' => {icon: 'file-text-o', appearance: 'success'},
    'category' => {icon: 'sitemap', appearance: 'info'},
    'category_order' => {icon: 'list-ul', appearance: 'info'},
    'product' => {icon: 'cube', appearance: 'info'},
    'promotion' => {icon: 'tag', appearance: 'info'},
    'department' => {icon: 'umbrella', appearance: 'info'},
    'header' => {icon: 'navicon'},
    'footer' => {icon: 'paragraph'},
    'dropdown' => {icon: 'files-o', appearance: 'primary'},
    'megamenu' => {icon: 'window-maximize', appearance: 'primary'},
    'continuous' => {icon: 'scissors', appearance: 'primary'},
    'contentmenu' => {icon: 'address-card-o', appearance: 'primary'},
    'template' => {icon: 'file-o', appearance: 'warning'},
    'portal' => {icon: 'globe', appearance: 'success'},
    'proxy' => {icon: 'share', appearance: 'success'},
    'external' => {icon: 'share', appearance: 'danger'},
    'internal' => {icon: 'share-alt', appearance: 'danger'},
  }.freeze

  #---
  belongs_to :store

  # Resource is anything the page may refer to, depending on its purpose.
  belongs_to :resource, polymorphic: true, optional: true

  has_many :sections, dependent: :destroy
  has_many :segments, -> { reorder('sections.priority, columns.priority, segments.priority') }, through: :sections
  has_many :content_pictures, through: :segments, source: :pictures

  default_scope { nested_set_scope }
  scope :live, -> { where(live: true) }
  scope :excluding, -> (page) { where.not(id: page) }

  # Containers for other pages. Segments target these to build navs.
  scope :container, -> { where(purpose: [10, 11, 20, 21, 22]) }

  #---
  validates :title, presence: true, if: :title_required?
  validates :slug, presence: true, uniqueness: {scope: :store}, format: {with: /\A[a-z0-9_-]+\z/}

  #---
  before_save :conditionally_disable
  after_save :touch_resource
  after_save :touch_ancestors
  after_save :touch_descendants

  #---
  # Finds the first valid entry point.
  def self.entry_point
    where(purpose: [0, 1, 2, 3, 4, 5, 6, 22, 43]).first
  end

  def self.available_purposes
    purposes.except :header, :footer
  end

  def self.purpose_options
    available_purposes.keys.map { |p| [Page.human_attribute_value(:purpose, p), p] }
  end

  def self.options_for_select(pages)
    [].tap do |options|
      each_with_level(pages) do |p, l|
        options << yield(p, l)
      end
    end
  end

  #---
  def inside?(page)
    page == self || is_descendant_of?(page)
  end

  def part_of_continuous_page?
    parent.present? && parent.continuous?
  end

  # The first primary child page is the front page for continuous pages.
  def front_page
    children.primary.live.first
  end

  def can_have_children?
    category? || header? || footer? || dropdown? || megamenu? || continuous?
  end

  def can_have_content?
    primary? || category? || product? || promotion? || department? || category_order? || template? || contentmenu? || portal?
  end

  def needs_resource?
    category? || product? || promotion? || department? || category_order? || portal? || proxy? || internal?
  end

  def movable?
    !(header? || footer?)
  end

  # Render subpages collapsed.
  def should_collapse?
    depth > 0
  end

  # Defines accessors to boolean settings not generated by Rails.
  %w[always_expand dynamic_navbar].each do |method|
    alias_method "#{method}?", method
    define_method("#{method}=") do |value|
      super(['1', 1, true].include?(value))
    end
  end

  # Pages needing a resource can be live if the resource is live, or
  # doesn't understand the concept of being live in the first place.
  def can_be_live?
    return true unless needs_resource?
    resource.present? && (!resource.respond_to?(:live) || resource.live?)
  end

  # Creates a duplicate containing duplicates of sections on this page.
  def duplicate!
    clone = dup.tap do |c|
      c.rename_as_copy
      c.slug = nil
      c.save
      sections.each do |section|
        c.sections << section.duplicate
      end
      pictures.each do |picture|
        c.pictures << picture.duplicate
      end
    end
  end

  # Creates a navigation menu by creating a link page to each item in
  # collection, recursively. The page purpose is determined by item class.
  def create_nav_menu!(collection)
    return if collection.none?

    collection.each do |item|
      page = store.pages.create!(
        parent: self,
        purpose: item.model_name.singular,
        title: item.to_s,
        live: true,
        resource: item
      )
      page.create_nav_menu!(item.children)
    end
  end

  def slugger
    title_required? ? [:title, [:title, :id]] : purpose
  end

  def title_required?
    !(header? || footer?)
  end

  def display_title
    return front_page.display_title if continuous? && front_page.present?
    title
  end

  def to_s
    title || human_attribute_value(:purpose)
  end

  def icon
    Page::PRESENTATION[purpose][:icon]
  end

  def appearance
    Page::PRESENTATION[purpose][:appearance]
  end

  def label
    return '' if header? || footer?
    return slug if route?
    resource || human_attribute_value(:purpose)
  end

  def description
    metadata[:description].presence || content
  end

  def content
    return front_page&.content if continuous? && front_page.present?
    if segment = segments.find { |segment| segment.content.present? }
      segment.content.truncate(250, separator: ' ', omission: '…')
    end
  end

  # Pages are rendered with partials corresponding to purpose.
  def to_partial_path
    "pages/purposes/#{purpose}"
  end

  # Purposes a page can switch to from existing ones.
  def available_purposes
    PURPOSE_CHAIN[purpose.to_sym] || [purpose]
  end

  def purpose_options
    available_purposes.map { |p| [Page.human_attribute_value(:purpose, p), p] }
  end

  # Route pages ask this method to render their links with
  # active_link_to, since the page with a slug of 'front'
  # should be active for all category and product pages.
  def active_link_options
    case slug
    when 'front'
      [['store'], ['show_category', 'show_product', 'show_promotion', 'show_department', 'show_category_order']]
    when 'cart'
      [['store'], ['cart']]
    end
  end

  protected
    # Adds an incrementing duplicate number to the title.
    def rename_as_copy
      trunk, branch = title.partition(/ \(\d+\)/)
      branch = ' (0)' if branch.empty?
      self[:title] = "#{trunk}#{branch.succ}"
    end

  private
    def touch_resource
      resource.touch if resource.present?
    end

    def touch_ancestors
      ancestors.map(&:touch)
    end

    def touch_descendants
      descendants.map(&:touch)
    end

    def conditionally_disable
      self.live = false unless can_be_live?
    end
end
