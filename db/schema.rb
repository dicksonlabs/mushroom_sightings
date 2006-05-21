# This file is autogenerated. Instead of editing this file, please use the
# migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.

ActiveRecord::Schema.define() do

  create_table "images", :force => true do |t|
    t.column "content_type", :string, :limit => 100
    t.column "title", :string, :limit => 100
    t.column "owner", :string, :limit => 100
    t.column "when", :date
    t.column "notes", :text
  end

  create_table "images_observations", :id => false, :force => true do |t|
    t.column "image_id", :integer, :default => 0, :null => false
    t.column "observation_id", :integer, :default => 0, :null => false
  end

  create_table "observations", :force => true do |t|
    t.column "created", :datetime
    t.column "modified", :datetime
    t.column "when", :date
    t.column "who", :string, :limit => 100
    t.column "where", :string, :limit => 100
    t.column "what", :string, :limit => 100
    t.column "specimen", :boolean, :default => false, :null => false
    t.column "notes", :text
    t.column "thumb_image_id", :integer
  end

end
