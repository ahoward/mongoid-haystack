## mongoid-haystack.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "mongoid-haystack"
  spec.version = "1.4.0"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "mongoid-haystack"
  spec.description = "a mongoid 3 zero-config, zero-integration, POLS pure mongo fulltext solution"

  spec.files =
["HISTORY",
 "README.md",
 "Rakefile",
 "article",
 "lib",
 "lib/app",
 "lib/app/models",
 "lib/app/models/mongoid",
 "lib/app/models/mongoid/haystack",
 "lib/app/models/mongoid/haystack/index.rb",
 "lib/app/models/mongoid/haystack/sequence.rb",
 "lib/app/models/mongoid/haystack/token.rb",
 "lib/mongoid-haystack",
 "lib/mongoid-haystack.rb",
 "lib/mongoid-haystack/index.rb",
 "lib/mongoid-haystack/search.rb",
 "lib/mongoid-haystack/sequence.rb",
 "lib/mongoid-haystack/stemming",
 "lib/mongoid-haystack/stemming.rb",
 "lib/mongoid-haystack/stemming/stopwords",
 "lib/mongoid-haystack/stemming/stopwords/english.txt",
 "lib/mongoid-haystack/stemming/stopwords/extended_english.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_danish.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_dutch.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_english.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_finnish.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_french.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_german.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_italian.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_norwegian.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_portuguese.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_russian.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_russiankoi8_r.txt",
 "lib/mongoid-haystack/stemming/stopwords/full_spanish.txt",
 "lib/mongoid-haystack/token.rb",
 "lib/mongoid-haystack/util.rb",
 "mongoid-haystack.gemspec",
 "test",
 "test/helper.rb",
 "test/mongoid-haystack_test.rb",
 "test/testing.rb"]

  spec.executables = []
  
  spec.require_path = "lib"

  spec.test_files = nil

  
    spec.add_dependency(*["mongoid", "~> 3.0"])
  
    spec.add_dependency(*["moped", "~> 1.3"])
  
    spec.add_dependency(*["origin", "~> 1.0"])
  
    spec.add_dependency(*["map", "~> 6.2"])
  
    spec.add_dependency(*["fattr", "~> 2.2"])
  
    spec.add_dependency(*["coerce", "~> 0.0"])
  
    spec.add_dependency(*["unicode_utils", "~> 1.4"])
  
    spec.add_dependency(*["threadify", "~> 1.3"])
  

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/mongoid-haystack"
end
