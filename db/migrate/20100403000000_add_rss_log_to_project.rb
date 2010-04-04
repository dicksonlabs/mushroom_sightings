class AddRssLogToProject < ActiveRecord::Migration
  def self.up
    add_column :rss_logs, :project_id, :integer
    add_column :projects, :rss_log_id, :integer
  end

  def self.down
    remove_column :rss_logs, :project_id
    remove_column :projects, :rss_log_id
  end
end
