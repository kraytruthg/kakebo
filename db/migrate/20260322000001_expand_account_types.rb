class ExpandAccountTypes < ActiveRecord::Migration[8.1]
  def up
    Account.where(account_type: "tracking").update_all(account_type: "tracking_asset")
  end

  def down
    Account.where(account_type: %w[tracking_asset tracking_liability]).update_all(account_type: "tracking")
  end
end
