#!/usr/bin/env ruby

require "erb"
require "yaml"
require "fileutils"

require "erb-hiera/version"
require "erb-hiera/cli"
require "erb-hiera/directory"
require "erb-hiera/hiera"
require "erb-hiera/manifest"

module ErbHiera
  class << self
    attr_accessor :options
  end

  def self.run
    @options = CLI.parse
    forked_pids = {}

    mappings.each do |mapping|
      if options[:fork] then
        child_pid = fork
        if child_pid then
          forked_pids[child_pid] = mapping
        else
          run_mapping(mapping)
        end
      else
        run_mapping(mapping)
      end
    end
    if options[:fork] then
      forked_statuses = Process.waitall
      p forked_statuses
      p forked_pids
    end
  rescue => error
    handle_error(error)
    exit 1
  end

  private

  def self.run_mapping(mapping)
    scope       = mapping["scope"]
    input       = mapping["dir"]["input"]
    output      = mapping["dir"]["output"]
    local_hiera = ::Hiera.new(:config => @options[:hiera_config])
    erb_hiera   = ErbHiera::Hiera.new(scope, @options[:verbose], local_hiera)

    [:input, :output].each do |location|
      raise StandardError, "error: undefined #{dir.to_s.split('_')[0]}put" unless binding.local_variable_get(location)
    end

    # if input is a file then out_file is a file too
    if input =~ /.erb$/
      generate(output, input, scope, erb_hiera)
      return
    end

    # otherwise the input/output are directories and all files should be processed..
    manifests(input).each do |manifest|
      out_file = File.join(output, manifest.gsub(input, ""))
      generate(out_file, manifest, scope, erb_hiera)
    end
  end

  def self.generate(out_file, manifest, scope, erb_hiera)
    Manifest.info(manifest, out_file, scope) if options[:verbose] || options[:info]

    erb = ERB.new(File.read(manifest), nil, "-").result(erb_hiera.get_binding())

    puts erb if options[:verbose]

    unless options[:dry_run]
      FileUtils.mkdir_p File.dirname(out_file) unless Dir.exists?(File.dirname(out_file))
      File.write(out_file, erb)
    end
  end

  def self.handle_error(error)
    if options[:debug]
      puts
      puts error.backtrace
    end

    puts
    puts error
  end

  def self.mappings
    YAML.load_file(options[:config])
  end

  def self.manifests(dir)
    Dir.glob(File.join(dir, "**", "*")).reject { |file| File.directory? file }
  end
end
