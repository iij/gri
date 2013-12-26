module GRI
  module Plugin
    extend Plugin

    def load_plugins dirs=[], config=nil
      @loaded = {}
      dirs += get_gem_dirs
      dirs.push File.join(File.dirname(__FILE__), 'plugin')
      dirs.each {|dir| load_plugin_dir dir, config}
    end

    def load_plugin_dir dir, config=nil
      dir = File.expand_path dir
      return unless File.exists? dir
      files = get_plugin_files dir, config
      files.each {|fname|
        unless @loaded[fname]
          path = File.join dir, fname
          require path
          @loaded[fname] = path
        end
      }
    end

    def get_plugin_files dir, config=nil
      files = Dir.entries(dir).sort.select {|fname| fname =~ /\A[^.].*\.rb$/}
      if config
        if config['enable-plugin']
          eps = config.getvar 'enable-plugin'
          files = files.select {|fname|
            s = fname.sub(/\.rb$/, '')
            eps.detect {|pname| pname == s}
          }
        end
        if config['disable-plugin']
          dps = config.getvar 'disable-plugin'
          files = files.select {|fname|
            s = fname.sub(/\.rb$/, '')
            !dps.detect {|pname| pname == s}
          }
        end
      end
      files
    end

    def get_gem_dirs
      dirs = []
      if Object.const_defined?(:Gem)
        if defined?(::Gem::Specification) and
            Gem::Specification.respond_to?(:find_all)
          specs = Gem::Specification.find_all {|spec|
            spec.full_require_paths.map {|path|
              File.directory?(path + '/gri/plugin')}.any?
          }.sort_by {|spec| spec.version}.reverse
          names = {}
          specs.each {|spec| names[spec.name] ||= spec}
          names.values.each {|spec|
            dirs += spec.full_require_paths.map {|path| path + '/gri/plugin'}
          }
        elsif Gem.respond_to?(:searcher)
          specs = Gem.searcher.find_all 'gri/plugin/*.rb'
          names = {}
          specs.sort_by {|spec| spec.version}.reverse.each {|spec|
            names[spec.name] ||= spec
          }
          names.values.each {|spec|
            files = Gem.searcher.matching_files spec, 'gri/plugin/*.rb'
            dirs += files.map {|fname| File.dirname fname}
          }
        end
      end
      dirs
    end
  end
end
