class PopulateMarketplaceUsername < ActiveRecord::Migration
  def up
    execute("UPDATE communities SET username = domain_alias")
    execute("UPDATE communities SET username = domain WHERE username = ''")
  end

  def down
  end
end
