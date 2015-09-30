$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.push File.expand_path('..', __FILE__)

require 'pry'
require 'sqlite3'
require 'active_record'

require 'flatter/extensions'

require 'support/ar_setup'
require 'support/spec_model'
