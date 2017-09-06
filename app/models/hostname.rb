#encoding: utf-8

class Hostname < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Reorderable

  #---
  belongs_to :store

  # Parent hostname provides domain/subdomains associations.
  belongs_to :domain_hostname, class_name: 'Hostname', foreign_key: :parent_hostname_id
  has_many :subdomain_hostnames, class_name: 'Hostname', foreign_key: :parent_hostname_id

  default_scope { sorted }

  # Hostnames assigned to store portals are semantically domains.
  scope :domain, -> { joins(:store).merge(Store.portal) }
  scope :subdomain, -> { where.not(domain_hostname: nil) }

  #---
  validates :fqdn, presence: true, uniqueness: true

  #---
  def to_url
    "//#{fqdn}"
  end

  def to_s
    fqdn
  end
end
