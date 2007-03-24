class SpeciesList < ActiveRecord::Base
  has_and_belongs_to_many :observations
  belongs_to :user
  has_one :rss_log
  attr_accessor :data

  def log(msg)
    if self.rss_log.nil?
      self.rss_log = RssLog.new
    end
    self.rss_log.addWithDate(msg, true)
  end
  
  def orphan_log(entry)
    self.log(entry) # Ensures that self.rss_log exists
    self.rss_log.species_list = nil
    self.rss_log.add(self.unique_text_name, false)
  end

  def species
    ''
  end
  
  def species=(list)
  end

  def file=(file_field)
    if file_field.kind_of?(StringIO)
      content_type = file_field.content_type.chomp
      if ('application/text' == content_type or 'text/plain' == content_type or 'application/octet-stream' == content_type)
        self.data = file_field.read
      else
        raise sprintf("Unrecognized content_type: %s\n", content_type)
      end
    else
      raise sprintf("Unrecognized file_field class: %s\n", file_field.class)
    end
  end
  
  # Process simple species lists of the form [<name>{\n\r}]+
  def process_simple_list(sorter)
    entry_text = self.data.split(/\s*[\n\r]\s*/)
    entry_text.each do |e|
      sorter.add_name(e.strip.squeeze(' '))
    end
  end
  
  # Process species lists that get generated by the Name species listing program
  def process_name_list(sorter)
    entry_text = self.data.gsub('[','').split(/\s*\r\]\r\s*/)
    entry_text.each do |e|
      timestamp = nil
      what = nil
      e.split(/\s*\r\s*/).each do |key_value|
        kv = key_value.split(/\s*\|\s*/)
        if kv.length != 2
          raise sprintf("Bad key|value pair (%s) in %s", key_value, filename)
        end
        key, value = kv
        if key == 'Date'
          timestamp = Time.local(*(ParseDate.parsedate(value)))
        elsif key == 'Name'
          what = value.strip.squeeze(' ')
        elsif key == 'Time'
          # Ignore
        else
          raise sprintf("Unrecognized key|value pair: %s\n", key_value)
        end
      end
      if what
        sorter.add_name(what, timestamp)
      end
    end
  end
  
  def process_file_data(sorter)
    if self.data
      if self.data[0] == 91 # '[' character
        process_name_list(sorter)
      else
        process_simple_list(sorter)
      end
    end
  end
  
  def unique_text_name
    title = self.title
    if title
      sprintf("%s (%d)", title[0..(MAX_FIELD_LENGTH-1)], self.id)
    else
      sprintf("Species List %d", self.id)
    end
  end
  
  def construct_observation(name, args)
    if name != ''
      args["what"] = name.search_name
      args["name_id"] = name.id
      if args["where"] == ''
        args["where"] = self.where
      end
      obs = Observation.new(args)
      obs.save
      self.observations << obs
    end
  end
  
  validates_presence_of :title
  validates_presence_of :where
end
