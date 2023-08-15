require 'json'

module Scenarios
  ##
  # ValidationChefResource scenario
  class ValidationChefResource
    attr_reader :opts

    def initialize(opts)
      @opts = opts
    end

    def run
      errors = []

      input = opts[:input]
      if(File.exist?(input))
        LOGGER.info "Working with #{input}"
      else
        raise "File '#{input}' not found"
      end

      consul_template = opts[:consul_template]
      raise "Consul template binary not found at #{consul_template}" unless File.exist?(consul_template)

      command = "#{consul_template} -template '#{input}' -once #{opts[:consul_template_args]} | tail -n +2"
      LOGGER.info "Template command: #{command}"

      begin
        resource = JSON.parse(`#{command}`)
      rescue JSON::ParserError => e
        LOGGER.error "Compiled template isn't a valid json: #{e.message}, stacktrace: \n\t#{e.backtrace.join("\n\t")}"
        exit(1)
      end

      LOGGER.info "Compiled template successfully parsed to hash"
      LOGGER.info "Resource class '#{resource['json_class']}', name '#{resource['name']}' validation started"

      unless ['Chef::Role', 'Chef::Environment'].include?(resource['json_class'])
        errors.push("Unsupported resource type '#{resource['json_class']}'")
      end

      if resource.has_key?('chef_type')
        errors.push('Resource contains invalid key \'chef_type\' - remove it!')
      end

      unless resource['name'] == File.basename(input,".json.tmpl")
        errors.push('File name does not match resource name - fix it!')
      end

      unless errors.empty?
        errors.each do |error|
          LOGGER.error error
        end

        exit(1)
      end

      LOGGER.info "Resource class '#{resource['json_class']}', name '#{resource['name']}' successfully validated"
    end
  end
end
