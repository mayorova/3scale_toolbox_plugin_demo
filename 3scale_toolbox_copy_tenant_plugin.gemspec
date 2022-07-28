# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = '3scale_toolbox_copy_tenant_plugin'
  spec.version       = '1.4.3'
  spec.licenses      = ['MIT']
  spec.authors       = ['Eguzki Astiz Lezaun']
  spec.email         = ['eastizle@redhat.com']

  spec.summary       = %q{3scale Toolbox Copy Tenant Plugin}
  spec.description   = %q{Copy complete tenants with 3scale Toolbox}
  spec.homepage      = 'https://github.com/mayorova/3scale_toolbox_plugin_demo'

  spec.files         = Dir['{lib}/**/*.rb'] + %w[README.md]
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_dependency '3scale_toolbox', '~> 0'
end
