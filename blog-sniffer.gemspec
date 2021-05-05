require_relative 'lib/blog/sniffer/version'

Gem::Specification.new do |spec|
  spec.name          = "blog-sniffer"
  spec.version       = Blog::Sniffer::VERSION
  spec.authors       = ["Jônatas Davi Paganini"]
  spec.email         = ["jonatasdp@gmail.com"]

  spec.summary       = %q{Sniff tech blog posts}
  spec.description   = %q{What are tech companies talking about?  Get some metadata from blog posts in the web.}
  spec.homepage      = "https://ideia.me"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
