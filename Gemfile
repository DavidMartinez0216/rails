path File.expand_path('..', __FILE__)
source :gemcutter

gem "rails", "3.0.pre"

gem "rake",  ">= 0.8.7"
gem "mocha", ">= 0.9.8"

if RUBY_VERSION < '1.9'
  gem "ruby-debug", ">= 0.10.3"
end

# AR
gem "sqlite3-ruby", ">= 1.2.5"

group :test do
  gem "pg", ">= 0.8.0"
  gem "mysql", ">= 2.8.1"
end

# AP
gem "rack-test", "0.5.3"
gem "RedCloth", ">= 4.2.2"

if ENV['CI']
  gem "nokogiri", ">= 1.4.0"
  gem "memcache-client", ">= 1.7.6"

  # fcgi gem doesn't compile on 1.9
  # avoid minitest strangeness on 1.9
  if RUBY_VERSION < '1.9.0'
    gem "fcgi", ">= 0.8.7"
  else
    gem "test-unit", ">= 2.0.5"
  end
end
