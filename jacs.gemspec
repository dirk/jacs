Gem::Specification.new do |s|
  s.name = 'jacs'
  s.version = '0.1'
  
  s.authors = ['Dirk Gadsden']
  s.date = '2010-05-14'
  s.description = 'Simple, distributed client-server communication using Jabber/XMPP.'
  s.summary = 'Client-server communication using Jabber/XMPP.'
  s.email = 'dirk@esherido.com'
  s.files = [
    'lib/jacs.rb',
    'lib/actionjabber.rb',
    'lib/activejabber.rb'
  ]
  s.extra_rdoc_files = [
    'LICENSE',
    'README.rdoc'
  ]
  s.homepage = 'http://esherido.com/'
  s.require_paths = ['lib']
  s.add_dependency('xmpp4r-simple', '>= 0.8.8')
  s.add_dependency('activesupport', '>= 2.3.5')
end