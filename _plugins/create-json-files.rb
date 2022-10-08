#!/usr/bin/env ruby

# This script creates an api/[product]/[version].json file for each releaseCycle
# in each markdown source file, where [product] is the permalink value and
# [version] is the releaseCycle value.
#
# The contents of the JSON files is the data in the releases, minus the
# releaseCycle.

require 'fileutils'
require 'json'
require 'yaml'
import 'date'

API_DIR = 'api'.freeze

class Product
  attr_reader :hash

  def initialize(markdown_file)
    @hash = YAML.load_file(markdown_file, permitted_classes: [Date])
  end

  def permalink
    hash.fetch('permalink').sub('/', '')
  end

  def release_cycles
    hash.fetch('releases').map do |release|
      name = release.delete('releaseCycle')
      { 'name' => name, 'data' => release }
    end
  end
end

# return a json output filename, including the directory name. Any / characters
# in the name are replaced with - to avoid file errors.
def json_filename(output_dir, name)
  filename = name.to_s.tr('/', '-') + '.json'
  File.join(output_dir, filename)
end

def process_product(product)
  output_dir = File.join(API_DIR, product.permalink)
  FileUtils.mkdir_p(output_dir) unless FileTest.directory?(output_dir)

  all_cycles = []
  product.release_cycles.each do |cycle|
    output_file = json_filename(output_dir, cycle.fetch('name'))
    File.open(output_file, 'w') { |f| f.puts cycle.fetch('data').to_json }
    all_cycles.append({'cycle' => cycle.fetch('name')}.merge(cycle.fetch('data')))
  end
  output_file = json_filename(API_DIR, product.permalink)
  File.open(output_file, 'w') { |f| f.puts all_cycles.to_json }
end

# each file is something like 'products/foo.md'
def process_all_files()
  all_products = []
  Dir['products/*.md'].each do |file|
    product = Product.new(file)
    product_cycles = process_product(product)
    all_products.append(product.permalink)
  end
  output_file = json_filename(API_DIR, 'all')
  File.open(output_file, 'w') { |f| f.puts all_products.sort.to_json }
end

############################################################

process_all_files()
