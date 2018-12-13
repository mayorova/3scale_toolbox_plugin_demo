# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = '3scale_toolbox_supercool_plugin'
  spec.version       = '1.1.0'
  spec.licenses      = ['MIT']
  spec.authors       = ['Eguzki Astiz Lezaun']
  spec.email         = ['eastizle@redhat.com']

  spec.summary       = %q{3scale Toolbox Supercool Plugin}
  spec.description   = %q{Supercool plugin does lots of things}
  spec.homepage      = 'https://github.com/eguzki/3scale_toolbox_plugin_demo'

  spec.files         = Dir['{lib}/**/*.rb'] + %w[README.md]
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_dependency '3scale_toolbox', '~> 0'
end
