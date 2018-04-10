lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'jira'
  spec.version       = '0.1.0'
  spec.authors       = ['Dmitry Shmelev']
  spec.email         = ['dmitry.shmelev@default.com']

  spec.summary       = 'OTT JIRA libs.'
  spec.description   = 'OTT JIRA libs.'
  spec.homepage      = 'https://www.onetwotrip.com'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = 'codereview'
  spec.require_paths = ['lib']
end
