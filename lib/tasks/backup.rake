## file : RAILS_ROOT/lib/tasks/backup.rake

namespace('backup') do

  namespace('dump') do
    ##
      task('all' => %w( dump:schema dump:tables dump:assets ))

    ##
      task 'schema' => %w( environment backup:connection ) do
        require 'active_record/schema_dumper'

        file = "#{ backup_dir }/schema/schema.rb"
        openw(file) do |fd|
          ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, fd)
        end
        puts file
      end

    ##
      task 'tables' => %w( environment backup:connection ) do
        sql = "SELECT * FROM %s"

        ActiveRecord::Base.connection.tables.each do |table_name|
          file = "#{ backup_dir }/tables/#{ table_name }.yml"
          openw("#{ backup_dir }/tables/#{ table_name }.yml") do |fd|
            records = ActiveRecord::Base.connection.select_all(sql % table_name)
            data = Hash.new
            records.each_with_index do |record, i|
              id = record['id']||record[:id]||(i + 1)
              data["#{ table_name }_#{ id }"] = record
            end
            fd.write(data.to_yaml)
          end
          puts file
        end
      end

      task 'assets' => %w( environment backup:connection ) do
        backup_assets.each do |asset|
          src = File.join(RAILS_ROOT, asset)
          dst = File.join(backup_dir, asset)
          if test(?d, src) and test(?d, dst)
            bak = dst + ".bak.#{ BACKUP_TIMESTAMP }"
            FileUtils.mv(dst, bak)
            FileUtils.cp_r(src, dst)
            puts dst
          end
        end
      end
  end

  namespace('load') do
  ##
    task('all' => %w( backup:load:schema backup:load:tables backup:load:assets ))

  ##
    task 'schema' => %w( environment backup:connection ) do
      backup_dir = ENV['BACKUP_DIR'] || ENV['DIR'] || ENV['BACKUP'] || ARGV.detect{|arg| test(?d, arg)}
      abort('no BACKUP_DIR') unless test(?d, backup_dir)

      load("#{ backup_dir }/schema/schema.rb")
    end

  ##
    task 'tables' => %w( environment backup:connection ) do
      backup_dir = ENV['BACKUP_DIR'] || ENV['DIR'] || ENV['BACKUP'] || ARGV.detect{|arg| test(?d, arg)}
      abort('no BACKUP_DIR') unless test(?d, backup_dir)

      require 'active_record/fixtures'
      Fixtures.class_eval do
        def parse_yaml_string(string)
          YAML::load(string)
        end
      end
      Dir.glob("#{ backup_dir }/tables/*.yml").each do |yml|
        dirname, basename = File.split(yml)
        base = File.basename(basename, '.yml')
        Fixtures.create_fixtures(dirname, base)
      end
    end

  ##
    task 'assets' => %w( environment backup:connection ) do
      backup_dir = ENV['BACKUP_DIR'] || ENV['DIR'] || ENV['BACKUP'] || ARGV.detect{|arg| test(?d, arg)}
      abort('no BACKUP_DIR') unless test(?d, backup_dir)

    # assets
      backup_assets.each do |asset|
        src = File.join(backup_dir, asset)
        dst = File.join(RAILS_ROOT, asset)
        if test(?d, dst)
          bak = dst + ".bak.#{ BACKUP_TIMESTAMP }"
          FileUtils.mv(dst, bak)
        end
        FileUtils.cp_r(src, dst)
      end
    end
  end





  ##
    task('connection' => %w( environment )) do
      @connection ||= ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[RAILS_ENV])
    end


  ##
    require 'fileutils'
    require 'time'

    BACKUP_TIMESTAMP = Time.now.iso8601(2).gsub(%r/[^\d]/,'')

    def backup_assets
      @backup_assets ||= Array(ENV['BACKUP_ASSETS'] || ENV['ASSETS'] || %w( private public/system )).join(',').strip.split(%r/\s*,\s*/)
    end

    def backup_name
      @backup_name ||= (ENV['BACKUP_NAME'] || ENV['NAME'] || BACKUP_TIMESTAMP)
    end

    def backup_dir
      unless defined?(@backup_dir)
        @backup_dir = ENV['BACKUP_DIR'] || ENV['DIR'] || ENV['BACKUP']
        unless @backup_dir
          @backup_dir = "#{ RAILS_ROOT }/backup/#{ RAILS_ENV }/#{ backup_name }/"
        end
        FileUtils.mkdir_p(@backup_dir) unless test(?d, @backup_dir)
      end
      @backup_dir
    end

    def openw(path, &block)
      FileUtils.mkdir_p(File.dirname(path))
      open(path, 'w', &block)
    end
end
