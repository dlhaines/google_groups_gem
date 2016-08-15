# ggb

This gem provides a simple Ruby interface to the Google API calls to manage Google Groups. See the 
test file for examples of how to use it.  See the file lib/ggb.rb for the actual implementation.

Only a limited number of methods, sufficient for the original project needs, have been surfaced and 
tested.  However much API specific information has been abstracted to the yaml configuration file and
the calls to the Google API are very short.  Adding additional method (and tests) should be straightforward.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ggb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ggb

## Usage

The default.yml.TEMPLATE file should be copied to a .yml file and the path and file name to appropriate
Google service account json credentials should be added.

A test file is available (`bundle exec rake test`) but it is specific to the original project and may require changes as may the
default.yml file.

See the test file for examples of how to write code to use the gem.


## Development

These instructions assume you are using _bundler_.

To install this gem onto your local machine, run `bundle exec rake install`. 

To generate a gem for local testing run:

    bundle exec rake build
    
Other projects can reference this gem via the path or git options.  E.g.
 * `gem "ggb", :path => "<local checkout of>/google_groups_gem"`
 * `gem 'ggb', :git => "https://github.com/tl-its-umich-edu/google_groups_gem.git", :tag => '<tag>'`

## Contributing

Bug reports and pull requests are welcome on GitHub for https://github.com/tl-its-umich-edu/google_groups_gem.

