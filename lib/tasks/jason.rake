namespace :jason do

  # ----------------------------
  #  Character encoding.
  # ----------------------------

  desc "Check for non-ISO-8859-1 characters in name authors."
  task(:check_for_special_characters => :environment) do
    print "Writing file \"y\"...\n"
    out = ""
    cd = Iconv.new('ISO-8859-1', 'UTF-8')
    for name in Name.find(:all)
      str = [
        name.id.to_s,
        name.text_name.to_s,
        name.author.to_s,
        name.citation.to_s,
        name.notes.to_s
      ].join("")
      out += str.gsub(/[ -~\t\r\n]/, '') + "\n"
    end
    out.gsub!(/\n+/, "\n")
    fh = File.open('y', 'w')
    fh.puts(out)
    fh.close
  end

################################################################################

  # ----------------------------
  #  Redcloth.
  # ----------------------------

  desc "Dump out all notes for obs, names, spls, comments to test RedCloth."
  task(:dump_notes => :environment) do
    notes = []
    for table in [
      'comments',
      'draft_names',
      'images',
      'licenses',
      'locations',
      'names',
      'naming_reasons',
      'namings',
      'notifications',
      'observations',
      'projects',
      'species_lists',
      'users',
      'votes',
    ]
      File.open('db/schema.rb', 'r') do |fh|
        table2 = nil
        fh.each_line do |line|
          if line.match(/^ +create_table +"(\w+)"/)
            table2 = $1
          elsif table == table2 && line.match(/^ +t.text +"(\w+)"/)
            column = $1
            print "Getting #{table} #{column}...\n"
            notes += Name.connection.select_values "SELECT DISTINCT #{column} FROM #{table}"
          end
        end
      end
    end
    print "Writing notes.yml...\n"
    File.open('notes.yml', 'w') do |fh|
      fh.write notes.select {|x| x && x.index('_')}.uniq.to_yaml
    end
    print "Done!\n"
  end

  desc "Convert all notes to HTML using textilize to test RedCloth."
  task(:test_redcloth => :environment) do
    include ActionView::Helpers::TextHelper # (for textilize)
    include ApplicationHelper
    notes = YAML::load(File.open('notes.yml'))
    print "Textilizing #{notes.length} strings...\n"
    n = 0
    results = []
    for str in notes
      if str.index('_')
        if n % 15 == 0
          print "%.2f%% done\n" % (100.0 * n / notes.length)
          sleep 1
        end
        n += 1
        begin
          results.push(str.tpl)
        rescue => e
          results.push('Crashed: ' + e.to_s + "\n" + str)
        end
      end
    end
    print "Writing redcloth.yml...\n"
    File.open('redcloth.yml', 'w') do |fh|
      fh.write results.map(&:to_yaml)
    end
    print "Done!\n"
  end

################################################################################

  desc "Get list of browser ID strings from apache logs."
  task(:apache_browser_ids) do
    require 'vendor/plugins/browser_status/lib/browser_status'
    include BrowserStatus
    ids = {}
    totals = {}
    for file in Dir.glob('../../../logs/access_log-*').sort
      File.open(file) do |fh|
        fh.each_line do |line|
          if match = line.match(/(\S+) \S+ \S+ \[([^\]]*)\] "([^"]*)" (\d+) (\d+) "([^"]*)" "([^"]*)"/)
            ua = match[7]
	    type, ver = parse_user_agent(ua)
	    str = ver ? "#{type}_#{ver}" : type.to_s || 'none'
            ids[ua] ||= [str, 0]
	    ids[ua][1] += 1
	    totals[str] ||= 0
	    totals[str] += 1
	  end
        end
      end
    end
    print ids.keys.
      sort_by {|ua| ids[ua][0]}.
      map {|ua| "#{ids[ua].join(' ')} #{ua}\n"}.
      join(''), "\n"
    print totals.keys.sort.
      map {|str| "#{str} #{totals[str]}\n"}.
      join('')
  end

################################################################################

  # ----------------------------
  #  Translations.
  # ----------------------------

  task(:get_localization_strings_used) do
    strings = {}
    for file in (
      Dir.glob('app/views/*/*.r*').sort +
      Dir.glob('app/controllers/*.rb').sort +
      Dir.glob('app/helpers/*.rb').sort +
      Dir.glob('app/models/*.rb').sort
    ) do
      File.open(file) do |fh|
        fh.each_line do |line|
          line.gsub(/:(\w+)\.(l|t|t_nop)($|\W)/) do
            strings[$1] = true
          end
        end
      end
    end
    @need_strings = strings
  end

  task(:get_localization_strings_available) do
    strings = {}
    File.open("lang/ui/#{ENV['LOCALE']}.yml") do |fh|
      fh.each_line do |line|
        if line.match(/^(\w+):/)
          strings[$1] = true
        end
      end
    end
    @have_strings = strings
  end

  desc "Print full list of localization strings used in the code."
  task(:print_localization_strings_used =>
    :get_localization_strings_used) do
    print @need_strings.keys.sort.join("\n") + "\n"
  end

  desc "Print full list of localization strings in a given localization file (use LOCALE=en-US, for example)."
  task(:print_localization_strings_available =>
    :get_localization_strings_available) do
    print @have_strings.keys.sort.join("\n") + "\n"
  end

  desc "Check to make sure all localization strings that are used are available (select language using LOCALE=en-US, for example)."
  task(:check_localizations => [
    :get_localization_strings_used,
    :get_localization_strings_available
  ]) do
    print @need_strings.keys.select {|key|
      !@have_strings.has_key?(key)
    }.sort.join("\n") + "\n"
  end

################################################################################

  # ----------------------------
  #  Esslinger's checklist.
  # ----------------------------

  desc "Upload names from Esslinger's checklist."
  task(:upload_esslinger => :environment) do
    user = User.find(252) # jason

    # This is stolen from construct_approved_names in app_controller.
    File.open('esslinger.txt') do |fh|
      fh.each_line do |name|
        name = name.strip!.squeeze(' ')
        if name.match(/^([A-Z])/)
          print $1

          name_parse = NameParse.new(name)
          results = Name.names_from_string(name_parse.search_name)
          if results.last.nil?
            print "\nError: #{name_parse.name}\n"
            name = nil
          else
            name = n = results.last
            n.rank  = name_parse.rank    if name_parse.rank
            n.notes = name_parse.comment if !n.id && name_parse.comment
            for n in results
              if n
                n.change_deprecated(false)
                n.save_if_changed(user, "Approved by jason, based on Esslinger's checklist.")
              end
            end
          end

          if name_parse.has_synonym
            results = Name.names_from_string(name_parse.synonym_search_name)
            if results.last.nil?
              print "\nError: = #{name_parse.synonym}\n"
            else
              synonym = n = results.last
              n.rank  = name_parse.synonym_rank    if name_parse.synonym_rank
              n.notes = name_parse.synonym_comment if !n.id && name_parse.synonym_comment
              n.change_deprecated(true)
              n.save_if_changed(user, "Deprecated by jason, based on Esslinger's checklist")
              for n in results[0..-2]
                n.save_if_changed(user, nil)
              end

              # Oops, forgot to actually synonymize names!
              name.merge_synonyms(synonym) if name and synonym
            end
          end

        end
      end
    end
  end

################################################################################

  desc "Convert __Names__ in notes throughout to links."
  task(:rebuild_links => :environment) do
    include ApplicationHelper
    str = "This looks a lot like _Agaricus_, like _A. campestris_ or _X. elegans_.\n"
    print str
    print str = check_other_links(check_name_links(str))
    print textilize(str)
  end

################################################################################

  desc 'Dump and flush mysqld stats.'
  task(:global_status => :environment) do
    for hash in Comment.connection.select_all('show global status')
      key = hash['Variable_name']
      val = hash['Value']
      printf "%-40.40s %s\n", key, val
    end
    Comment.connection.execute('flush status')
  end

################################################################################

  desc 'Bulk create observations.'
  task(:bulk => :environment) do
    user = User.find_by_login('jason')
    path = '/home/jason'

    # Collect image objects we've already uploaded, allowing us to share images
    # between observations.
    done_images = Hash.new

    # Do one object at a time.  Read lines one at a time until reach start of
    # next object.  Leave that line in "line" for next iteration, then process
    # the present object.
    line = $stdin.gets
    while line
      line.chomp!
      lines = [line]

      # Skip blank lines and comments.
      if line.match(/^\s*(#|$)/)
        line = $stdin.gets

      # Create new observation.
      elsif line == 'OBSERVATION'
        date   = nil
        where  = nil
        what   = nil
         vote   = nil
         sight  = nil
         refs   = nil
         chem   = nil
         micro  = nil
        spec   = nil
        is_co  = nil
        notes  = nil
        images = []

        line = $stdin.gets
        while line && !line.match(/^[A-Z]/)
          line.chomp!

          # All items for an object are of the form: "var: val"
          if line.match(/^(\w[\w\s]+\w)\s*:\s*(.*)/)
            var = $1
            val = $2
            lines.push(line)
            var.gsub!(/[\s_]+/, ' ')

            # If val is "\" then slurp any subsequent indented lines.
            if val == '\\'
              val = ''
              line = $stdin.gets
              while line && !line.match(/^\w/)
                line.chomp!
                lines.push(line)
                if !line.match(/^\s*#/)
                  val += "\n" if val != ''
                  val += line.sub(/^\s+/, '')
                end
                line = $stdin.gets
              end
              val.sub!(/\s+\Z/, '')
            else
              line = $stdin.gets
            end

            case var
            when 'where'
              if !where.nil?
                lines.push('>>>>>>>> already set "where" for this observation')
              else
                where = lookup_location(val, lines)
                where = true if !where # (lookup_location takes care of errors)
              end
            when 'specimen'
              if !spec.nil?
                lines.push('>>>>>>>> already set "specimen" for this observation')
              elsif val.match(/^(y(es)?|1)$/i)
                spec = true
              elsif val.match(/^(n(o)?|0)$/i)
                spec = false
              else
                lines.push('>>>>>>>> unrecognized value, please use "yes" or "no"')
                spec = true
              end
            when 'is collection location'
              if !is_co.nil?
                lines.push('>>>>>>>> already set "is collection location" for this observation')
              elsif val.match(/^(y(es)?|1)$/i)
                is_co = true
              elsif val.match(/^(n(o)?|0)$/i)
                is_co = false
              else
                lines.push('>>>>>>>> unrecognized value, please use "yes" or "no"')
                is_co = true
              end

            when 'what'
              if !what.nil?
                lines.push('>>>>>>>> already set "what" for this observation')
              else
                what = lookup_name(val, lines)
                what = true if !what # (lookup_name takes care of errors)
              end
            when 'vote'
              if !what
                lines.push('>>>>>>>> haven\'t set "what" for this observation yet')
              elsif !vote.nil?
                lines.push('>>>>>>>> already set "vote" for this observation')
              elsif val.match(/call/i)
                vote = 3
              elsif val.match(/promis/i)
                vote = 2
              elsif val.match(/could/i)
                vote = 1
              elsif val.match(/doubt/i)
                vote = -1
              elsif val.match(/not/i)
                vote = -2
              elsif val.match(/as[\s_]if/i)
                vote = -3
              else
                lines.push('>>>>>>>> invalid vote, use "I\'d call it that", "promising" or "could be"')
              end
            when /^by sight$/
              if !what
                lines.push('>>>>>>>> haven\'t set "what" for this observation yet')
              elsif !sight.nil?
                lines.push('>>>>>>>> already set "by sight" for this observation')
              else
                sight = val
              end
            when /^(used )?ref(erence)?s$/
              if !what
                lines.push('>>>>>>>> haven\'t set "what" for this observation yet')
              elsif !refs.nil?
                lines.push('>>>>>>>> already set "used refs" for this observation')
              else
                refs = val
              end
            when /^(by )?chem\w*/
              if !what
                lines.push('>>>>>>>> haven\'t set "what" for this observation yet')
              elsif !chem.nil?
                lines.push('>>>>>>>> already set "chemistry" for this observation')
              else
                chem = val
              end
            when /^(by )?micro\w*/
              if !what
                lines.push('>>>>>>>> haven\'t set "what" for this observation yet')
              elsif !micro.nil?
                lines.push('>>>>>>>> already set "microscopic" for this observation')
              else
                micro = val
              end

            when 'image'
              if !(file = lookup_image(val, path))
                lines.push('>>>>>>>> couldn\'t find image "%s"' % val)
              end
              images.push([file,nil,nil,nil])
            when 'who'
              if images.empty?
                lines.push('>>>>>>>> missing image')
              elsif images.last[1]
                lines.push('>>>>>>>> already set "image name" for this image')
              else
                images.last[1] = val
              end
            when 'when'
              if images.empty?
                if !date.nil?
                  lines.push('>>>>>>>> already set "when" for this observation')
                elsif !(date = Date.strptime(val, '%Y%m%d'))
                  lines.push('>>>>>>>> couldn\'t parse date, use YYYYMMDD')
                  date = true
                end
              elsif images.last[2]
                lines.push('>>>>>>>> already set "image date" for this image')
              elsif !(images.last[2] = Date.strptime(val, '%Y%m%d'))
                lines.push('>>>>>>>> couldn\'t parse date, use YYYYMMDD')
                images.last[2] = true
              end
            when 'notes'
              if images.empty?
                if !notes.nil?
                  lines.push('>>>>>>>> already set "notes" for this observation')
                else
                  notes = val
                end
              elsif images.last[3]
                lines.push('>>>>>>>> already set "notes" for this image')
              else
                images.last[3] = val
              end

            else
              lines.push('>>>>>>>> unrecognized field')
            end

          else
            # Keep blank lines and comments in case of error.
            if line.match(/^\s*(#|$)/)
              lines.push(line)
            else
              lines.push('>>>>>>>> %s' % line)
            end
            line = $stdin.gets
          end
        end

        lines.push('>>>>>>>> missing "where"') if !where
        lines.push('>>>>>>>> missing "vote"')  if what && !vote

        if lines.select {|l| l.match(/^>>>>/)}.empty?
          date  ||= Date.today
          spec  ||= false
          is_co ||= true

          obs = Observation.new
          obs.when       = date
          obs.notes      = notes
          obs.specimen   = spec
          obs.user_id    = user.id
          obs.is_collection_location = is_co
          obs.created = obs.modified = Time.now
          obs.name_id = what.id if what
          if where.is_a?(Location)
            obs.where = where.name
            obs.location = where
          else
            obs.where = where
          end

          if obs.save
            if notes.match(/(\d{8}\.\d+\w*)/)
              name = $1
            elsif what
              name = '%s %s' % [date.strftime('%Y%m%d'), what.text_name]
            else
              name = 'unknown'
            end
            $stderr.puts('Created observation: #%d (%s)' % [obs.id, name])
            obs.log(:log_observation_created, { :user => user.login }, true)
            lines.clear

            # Create naming if "what" given.
            if what
              naming = Naming.new
              naming.created        = obs.created
              naming.modified       = obs.created
              naming.observation_id = obs.id
              naming.name_id        = what.id
              naming.user_id        = user.id

              # Attach to observation if creates successfully.
              if naming.save
                NamingReason.new(:naming => naming, :reason => 1, :notes => sight).save if sight 
                NamingReason.new(:naming => naming, :reason => 2, :notes => refs).save  if refs
                NamingReason.new(:naming => naming, :reason => 3, :notes => chem).save  if chem
                NamingReason.new(:naming => naming, :reason => 4, :notes => micro).save if micro 
                naming.change_vote(user, vote)
                $stderr.puts('  Created naming: #%d (%s)' % [naming.id, naming.name.search_name])
              else
                $stderr.puts('Failed to create naming: %s' % naming.dump_errors)
              end
            end

            # Create images now.
            for file, name, date, notes in images

              # Just attach any (shared) images we've already created.
              if (image = file).is_a?(Image) || (image = done_images[file])
                obs.images.push(image)
                if !obs.thumb_image_id
                  obs.thumb_image_id = image.id
                  obs.save
                end

              else
                upload = FakeUpload.new
                upload.path = file
                upload.content_type = 'image/jpeg'

                # Create new image.
                image = Image.new
                image.created          = obs.created
                image.modified         = obs.created
                image.user_id          = user.id
                image.when             = date || obs.when
                image.notes            = notes if notes
                image.copyright_holder = name || user.legal_name
                image.license_id       = user.license_id
                image.image            = upload

                # Attach to observation if creates successfully.
                if image.save && image.save_image
                  done_images[file] = image
                  obs.images.push(image)
                  if !obs.thumb_image_id
                    obs.thumb_image_id = image.id
                    obs.save
                  end
                  $stderr.puts('  Created image: #%d' % image.id)
                else
                  $stderr.puts('Failed to create image "%s": %s' % [file, image.dump_errors])
                end
              end
            end

          else
            lines.push('>>>>>>>> couldn\'t create observation: %s' % obs.dump_errors)
          end
        end

        for x in lines
          puts(x)
        end

      elsif line.match(/^[A-Z]/)
        puts('>>>>>>>> unrecognized object type')
        begin
          line.chomp!
          puts(line)
          line = $stdin.gets
        end while line && !line.match(/^[A-Z]/)

      else
        puts('>>>>>>>> expected object type')
        begin
          line.chomp!
          puts(line)
        end while line = $stdin.gets
      end
    end
  end

  def lookup_location(val, lines)
    force = val.sub!(/\*$/, '')
    loc = Location.search_by_name(val)
    if force
      loc ||= val
    elsif !loc
      val2 = val.downcase.gsub(/\W+/, ' ')
      results = Location.find(:all, :conditions => "search_name like '%#{val2}%'", :order => "name asc")
      if results.length == 0
        lines.push('>>>>>>>> couldn\'t find any matching locations (add "*" to end to create)')
      elsif results.length == 1
        loc = results.first
      elsif results.length > 1
        lines.push('>>>>>>>> multiple locations match: (add "*" to end to create)')
        for x in results
          lines.push('>>>>>>>>   %s' % x.name)
        end
      end
    end
    return loc
  end

  def lookup_name(val, lines)
    force = val.sub!(/\*$/, '')
    val = val.squeeze(' ').strip.gsub('_', ' ')
    names = Name.find_names(val)
    valid_names = names.reject {|n| n.deprecated}
    synonyms = names.first.approved_synonyms.sort if names.first
    if names.length == 0
      lines.push('>>>>>>>> unrecognized name, please correct or create by hand')
    elsif force
      return names.first  
    elsif !names.first.deprecated && valid_names.length == 1
      return names.first
    elsif !names.first.deprecated && valid_names.length > 1
      lines.push('>>>>>>>> multiple names match: (add "*" to end to force)')
      for name in valid_names
        lines.push('>>>>>>>>   %s' % name.search_name)
      end
    else
      lines.push('>>>>>>>> name is deprecated, accepted names/synonyms are: (add "*" to end to force)')
      if valid_names.length == 0 && synonyms.length == 0
        lines.push('>>>>>>>>   none available?!')
      end
      for name in valid_names + synonyms
        lines.push('>>>>>>>>   %s' % name.search_name)
      end
    end
    return nil
  end

  def lookup_image(val, path)
    if val.match(/^\d+$/)
      return Image.find_by_id(val)
    # elsif val.match(/^https?:\/\//)
    #   ...
    elsif File.exists?(val)
      return val
    elsif File.exists?(file = '%s.jpg' % val)
      return file
    elsif File.exists?(file = '%s/%s' % [path, val])
      return file
    elsif File.exists?(file = '%s/%s.jpg' % [path, val])
      return file
    else
      return nil
    end
  end

  class FakeUpload
    attr_accessor :path
    attr_accessor :content_type
    def size; File.size(path); end
  end

################################################################################

  desc "test"
  task(:test => :environment) do
    user = User.find(252)
    AccountMailer.deliver_user_question(user, user, 'test', 'test')
  end
end
