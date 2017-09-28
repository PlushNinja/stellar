#encoding: utf-8

class RoleAuthorizer < ApplicationAuthorizer

  def self.updatable_by?(user, opts)
    user.has_cached_role?(:user_manager, opts[:at])
  end
end
