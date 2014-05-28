Gem::Specification.new { |s|
  s.platform = Gem::Platform::RUBY

  s.license = 'MIT'
  s.author = "CodeWars"
  s.email = 'info@codewars.com'
  s.files = Dir["{lib,doc,bin,ext}/**/*"].delete_if {|f|
    /\/rdoc(\/|$)/i.match f
  } + %w(Rakefile)
  s.require_path = 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = (Dir['doc/*'] << 'README.md').select(&File.method(:file?))
  s.extensions << 'ext/extconf.rb' if File.exist? 'ext/extconf.rb'
  Dir['bin/*'].map(&File.method(:basename)).map(&s.executables.method(:<<))

  s.name = 'code-grouper'
  s.summary = "code-grouper matches and groups snippets of code in various languages."
  s.description = <<-EOF.gsub!(/^\s+/, '')
    The purpose of this gem is to match and group related snippets of code
    for various languages.

    The intent of this gem is to not just to reduce code down to its most
    minimal form.  An attempt to preserve good coding conventions is made.
  EOF
  s.homepage = "https://github.com/Codewars/code-grouper"
  %w().each &s.method(:add_dependency)
  %w(rspec).each &s.method(:add_development_dependency)
  s.version = '0.1.0'
}
