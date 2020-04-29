namespace "vendor" do
  def vendor(*args)
    return File.join("vendor", *args)
  end

  task "jruby" do |task, args|
    system('./gradlew downloadAndInstallJRuby') unless File.exists?(File.join("vendor", "jruby"))
  end # jruby

  namespace "force" do
    task "gems" => ["vendor:gems"]
  end

  task "gems", [:bundle] do |task, args|
    require "bootstrap/environment"

    Rake::Task["dependency:clamp"].invoke
    Rake::Task["dependency:bundler"].invoke

    puts("Invoking bundler install...")
    output, exception = LogStash::Bundler.invoke!(:install => true)
    puts(output)
    raise(exception) if exception
  end # task gems
  task "all" => "gems"

  # This is terrible but is the fastest fix for the mess that is gems in this repo.
  # Basically, the Gemfile (and all gems) get packaged. This ends up causing issues
  # with custom plugins that have gem dependencies that don't align with some of the
  # build dependencies. There's a real fix in here somewhere but we need this now and
  # I'm tired.
  task "package_gems", [:bundle] do |task, args|
    puts("Blow away vendor/bundle directory and re-install only the gems needed for runtime.")
    Rake::Task["vendor:clean_bundle"].execute

    require "bootstrap/environment"

    puts("Re-install bundler since we blew it away in the previous step and logstash needs it for plugin tasks")
    Rake::Task["gem:install"].execute(:name => "bundler", :requirement => "~> 2.1.4", :target => LogStash::Environment.logstash_gem_home)

    puts("Re-install rake since we blew it away in the previous step and logstash needs it for plugin tasks")
    Rake::Task["gem:install"].execute(:name => "rake", :requirement => "~> 12.2.1", :target => LogStash::Environment.logstash_gem_home)

    puts("Delete Gemfile and Gemfile.lock so the are recreated using the Gemfile.runtime_template")
    gemfiles = ['Gemfile', 'Gemfile.lock']
    File.delete(*gemfiles)

    puts("Invoking bundler install using Gemfile.runtime_template...")
    output, exception = LogStash::Bundler.invoke!(:install => true, :clean => true, :without => [:development, :build], :gemfile_template => 'Gemfile.runtime_template')
    puts(output)
    raise(exception) if exception
  end # task package_gems

  desc "Clean the vendored files"
  task :clean do
    rm_rf(vendor)
  end

  desc "Clean the vendor/bundle files"
  task :clean_bundle do
    rm_rf(vendor(["bundle"]))
  end
end
