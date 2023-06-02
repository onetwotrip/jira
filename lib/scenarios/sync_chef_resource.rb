require 'chef-api'
require 'json'

module Scenarios
  ##
  # SyncChefResource scenario
  class SyncChefResource
    attr_reader :opts

    def initialize(opts)
      @opts = opts
    end

    def run
      input = opts[:input]
      if (File.exist?(input))
        LOGGER.info "Working with #{input}"
      else
        raise "File '#{input}' not found"
      end

      consul_template = opts[:consul_template]
      raise "Consul template binary not found at #{consul_template}" unless File.exist?(consul_template)

      output = '/tmp/' + File.basename(input, '.tmpl')
      command = "#{consul_template} -template '#{input}:#{output}' -once #{opts[:consul_template_args]}"
      LOGGER.info "Template command: #{command}"
      system("#{command}", exception: true)
      LOGGER.info "Success, created file #{output}"

      output_content = File.read(output)
      begin
        resource = JSON.parse(output_content)
      rescue JSON::ParserError => e
        LOGGER.error "Output file isn't a valid json: #{e.message}, stacktrace: \n\t#{e.backtrace.join("\n\t")}"
        exit(1)
      end
      File.delete(output)

      LOGGER.info "Output file (#{output}) successfully parsed to hash, deleted it"
      LOGGER.info "Resource class #{resource['json_class']}, name #{resource['name']}"

      chef_object =
        case resource['json_class']
        when 'Chef::Role'
          ChefAPI::Resource::Role.fetch(resource['name'])
        when 'Chef::Environment'
          ChefAPI::Resource::Environment.fetch(resource['name'])
        else
          raise "Unsupported resource type #{resource['json_class']}"
        end

      chef_object.update(resource)
      chef_object.save
      LOGGER.info "#{resource['json_class']} #{resource['name']} successfully updated"
    end
  end
end
