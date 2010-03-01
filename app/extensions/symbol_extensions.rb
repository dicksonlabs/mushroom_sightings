#
#  = Extensions to Symbol
#  == Instance Methods
#
#  localize:: Wrapper on Globalite#localize.
#  l::        Alias for localize.
#  t::        Localize, textilize (no paragraphs or obj links).
#  tl::       Localize, textilize with obj links (no paragraphs).
#  tp::       Localize, textilize with paragraphs (no obj links).
#  tpl::      Localize, textilize with paragraphs and obj links.
#
################################################################################

class Symbol
  if !defined? old_localize
    alias old_localize localize
  end

  # Converts Symbol directly to lowercase, without making you go through String.
  def downcase
    to_s.downcase.to_sym
  end

  # Converts Symbol directly to uppercase, without making you go through String.
  def upcase
    to_s.upcase.to_sym
  end

  # Capitalizes first letter of Symbol directly, without making you go through
  # String.
  def capitalize
    to_s.capitalize.to_sym
  end

  # Capitalizes just the first letter of Symbol directly, without making you go
  # through String.  (+capitalize+ does <tt>downcase.capitalize_first</tt>)
  def capitalize_first
    to_s.capitalize_first.to_sym
  end

  # Run +localize+ in test mode.
  def test_localize(*args) # :nodoc:
    @@test = true
    result = localize(*args)
    @@test = false
    return result
  end
  @@test = false

  # Wrapper on the old +localize+ method that:
  # 1. converts '\n' into newline throughout
  # 2. maps '[arg]' via optional hash you can pass in
  # 3. expands recursively-embedded tags like '[:tag]' and '[:tag(:key=val)]'
  #    or '[:tag1(:key=>:tag2)]' (but no deeper).
  #
  # There are several related wrappers on localize:
  # t::   Textilize: no paragraphs or links or anything fancy.
  # tl::  Do 't' and check for links.
  # tp::  Wrap 't' in a <p> block.
  # tpl:: Wrap 't' in a <p> block AND do links.
  #
  # ==== Argument expansion
  #
  # It supports some limited attempts to get case and number correct.  This
  # feature only works it the value passed in is a Symbol.  For example:
  #
  #   :tag.l(:type => :login)
  #
  #   # Given these definitions:
  #   LOGIN: Nombre de Usuario
  #   login: nombre de usuario
  #   LOGINS: Nombres de Usuario
  #   logins: nombres de usuario
  #
  #   # Yields these:
  #   tag1: Por favor, entrar [type].    =>  Por favor, entrar nombre de usuario.
  #   tag2: Ninguno [types] encontrados. =>  Ninguno nombres de usuario encontrados.
  #   tag3: [Type] desaparecidos.        =>  Nombre de usuario desaparecidos.
  #   tag4: [Types] son necesarios.      =>  Nombres de usuario son necesarios.
  #   title1: Cambio de [TYPE]           =>  Cambio de Nombre de Usuario
  #   title2: Todos los [TYPES]          =>  Todos los Nombres de Usuario
  #
  # This allows German to capitalize all of the above, since all major nouns
  # are capitalized even in normal sentences.  And it allows the translator to
  # use plural if it makes more sense in their language, even if we used
  # singular in English.  And it allows translators to feel free to place a
  # word at the beginning of the sentece even if we didn't in English.
  #
  # *NOTE*: No case is enforced on literal Strings passed in, such as, for
  # example, user or observation names.
  #
  # ==== Recursively-Embedded Tags::
  #
  # Tag definitions are allowed to embed references to other tags.
  #
  #   [:alpha]
  #   [:alpha(alpha=almost_anything,alpha=almost_anything,...)]
  #
  # Where "almost_anything" is anything but , = () [] or \n.  If it looks like
  # a symbol (i.e. is ":alpha"), then it is converted into one.  If it is just
  # alphanumeric, then it is assumed to be an arg from the parent's hash.
  # Otherwise it must start and end with single-quotes.  Any additional single
  # quotes inside are preserved as-is.
  #
  #   [:tag(type=:name)]                 ==  :tag.l(:type => :name)
  #   [:tag(type=parent_arg)]            ==  :tag.l(:type => args[:parent_arg])
  #   [:tag(type='Literal Value')]       ==  :tag.l(:type => "Literal Value")
  #   [:tag(type=''Quote's Are Kept'')]  ==  :tag.l(:type => "'Quote's Are Kept'")
  #
  # *NOTE*: Square brackets are NOT allowed in the literals, even if quoted!
  # That would make the parsing non-trivial and potentially slow.
  #
  def localize(args={}, level=[])
    capitalize_result = false
    unless (@@test and (
             (result = args[self]) or 
             ((result = args[downcase]) and (capitalize_result = true))
           )) or (
             (result = Globalite.localize(self, nil, {})) or
             ((result = Globalite.localize(downcase, nil, {})) and (capitalize_result = true))
           )
      result = "[:#{self}]"
    end

    if result.is_a?(String)
      # Replacing "\n" with newlines is easy...
      result.gsub!(/ *\\n */, "\n")

      # Expand arguments.  (See comments above.)
      if args.is_a?(Hash)
        result.gsub!(/\[(\w+?)\]/) do
          x = y = $1

          # Want :type, given :type.
          if args.has_key?(arg = x.to_sym)
            val = args[arg]
            val.is_a?(Symbol) ?
              val.l :
              val.to_s

          # Want :types, given :type.
          elsif (y = x.sub(/s$/i,'')) and
                args.has_key?(arg = y.to_sym)
            val = args[arg]
            val.is_a?(Symbol) ?
              "#{val}s".to_sym.l :
              val.to_s

          # Want :TYPE, given :type.
          elsif args.has_key?(arg = x.downcase.to_sym) and
                (x == x.upcase)
            val = args[arg]
            val.is_a?(Symbol) ?
              val.to_s.upcase.to_sym.l :
              val.to_s.capitalize_first

          # Want :TYPES, given :type.
          elsif args.has_key?(arg = y.downcase.to_sym) and
                (y == y.upcase)
            val = args[arg]
            val.is_a?(Symbol) ?
              "#{val.to_s.upcase}S".to_sym.l :
              val.to_s.capitalize_first

          # Want :Type, given :type.
          elsif args.has_key?(arg = x.downcase.to_sym)
            val = args[arg]
            val.is_a?(Symbol) ?
              val.l.capitalize_first :
              val.to_s.capitalize_first

          # Want :Types, given :type.
          elsif args.has_key?(arg = y.downcase.to_sym)
            val = args[arg]
            val.is_a?(Symbol) ?
              "#{val}s".to_sym.l.capitalize_first :
              val.to_s.capitalize_first

          else
            raise(ArgumentError, "Forgot to pass :#{y.downcase} into localization for " +
                                 ([self] + level).map(&:inspect).join(' --> '))
          end
        end
      end

      # Expand recursively-embedded tags.  Matches anything of these two types:
      #
      #   [:alpha]
      #   [:alpha(alpha=almost_anything,alpha=almost_anything,...)]
      #
      # Where "almost_anything" is anything but , = () [] or \n.  If it looks
      # like a symbol (i.e. is ":alpha"), then it is converted into one.  If
      # it is just alphanumeric, then it is assumed to be an arg from the
      # parent's hash.  Otherwise it must start and end with single-quotes.
      # Any additional single quotes inside are preserved as-is.
      #
      #   [:tag(type=:name)]                 ==  :tag.l(:type => :name)
      #   [:tag(type=parent_arg)]            ==  :tag.l(:type => args[:parent_arg])
      #   [:tag(type='Literal Value')]       ==  :tag.l(:type => "Literal Value")
      #   [:tag(type=''Quote's Are Kept'')]  ==  :tag.l(:type => "'Quote's Are Kept'")
      #
      # NOTE: Square brackets are NOT allowed in the literals, even if quoted!
      # That would make the parsing non-trivial and potentially slow.
      #
      result.gsub!(/ \[ :(\w+?) (?:\( ([^\(\)\[\]]+) \))? \] /x) do
        tag = $1.to_sym
        args2 = $2.to_s
        hash = args.dup
        if args2 != ''
          args2.split(',').each do |pair|
            if pair.match(/^:?([a-z]+)=(.*)$/)
              key = $1.to_sym
              val = $2.to_s
              if val.match(/^:(\w+)$/)
                val = $1.to_sym
              elsif val.match(/^"(.*)"$/) ||
                    val.match(/^'(.*)'$/) ||
                    val.match(/^(-?\d+(\.\d+)?)$/)
                val = $1
              elsif !val.match(/^([a-z][a-z_]*\d*)$/)
                raise(ArgumentError, "Invalid argument value \":#{val}\" in localization for " +
                                       ([self] + level).map(&:inspect).join(' --> '))
              elsif !args.has_key?(val.to_sym)
                raise(ArgumentError, "Forgot to pass :#{val} into localization for " +
                                       ([self] + level).map(&:inspect).join(' --> '))
              else
                val = args[val.to_sym]
              end
              hash[key] = val
            else
              raise(ArgumentError, "Invalid syntax at \"#{pair}\" in arguments " +
                                   "for tag :#{tag} embedded in " +
                                   ([self] + level).map(&:inspect).join(' --> '))
            end
          end
        end
        tag.l(hash, level+[self])
      end if level.length < 8
    end

    # Make token attempt to capitalize result if requested [:TAG] for :tag.
    capitalize_result ? result.capitalize_first : result
  end

  alias l localize

  def t(*args); localize(*args).t; end
  def tl(*args); localize(*args).tl; end
  def tp(*args); localize(*args).tp; end
  def tpl(*args); localize(*args).tpl; end
end
