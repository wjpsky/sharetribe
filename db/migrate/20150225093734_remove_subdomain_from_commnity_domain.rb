class RemoveSubdomainFromCommnityDomain < ActiveRecord::Migration
  def up
    execute("UPDATE communities SET domain = NULL WHERE INSET(domain, '.') = 0")
  end

  def down
    # Should we have something here?
  end
end
