require 'rubygems/package_task'
require 'rdoc/task'
require 'rspec/core/rake_task'

$: << "#{File.dirname(__FILE__)}/lib"

spec = eval File.read(Dir['*.gemspec'][0])

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

Rake::RDocTask.new(:doc) { |t|
  t.main = 'README'
  t.rdoc_files.include 'lib/**/*.rb', 'doc/*', 'bin/*', 'ext/**/*.c',
    'ext/**/*.rb'
  t.options << '-S' << '-N'
  t.rdoc_dir = 'doc/rdoc'
}

Gem::PackageTask.new(spec) { |pkg|
  pkg.need_tar_bz2 = true
}
desc "Cleans out the packaged files."
task(:clean) {
  FileUtils.rm_rf 'pkg'
}


desc "Runs IRB, automatically require()ing #{spec.name}."
task(:irb) {
  exec "irb -Ilib -rcode_comparer"
}

desc "Like the irb task, but with settings to accomodate running it in an editor rather than a terminal (e.g., acme, emacs)."
task(:airb) {
  exec "irb -Ilib -rcode_comparer --prompt default --noreadline"
}
