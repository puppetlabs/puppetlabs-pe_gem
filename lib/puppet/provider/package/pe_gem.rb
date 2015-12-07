require 'puppet/provider/package'
require 'uri'

# Ruby gems support.
Puppet::Type.type(:package).provide :pe_gem, :parent => :gem do
  desc "Puppet Enterprise Ruby Gem support. If a URL is passed via `source`, then
    that URL is used as the remote gem repository; if a source is present but is
    not a valid URL, it will be interpreted as the path to a local gem file.  If
    source is not present at all, the gem will be installed from the default gem
    repositories."

  has_feature :versionable, :install_options
  if Facter.value(:kernel) == 'windows'
    commands :gemcmd => "gem"
  else
    commands :gemcmd => "/opt/puppet/bin/gem"
  end

  def self.instances
    if Puppet[:version].to_f >= 4.0
      warn "DEPRECATION: As of Puppet 4.0, the pe_gem provider for the package resource has been deprecated. Please use the puppet_gem provider instead."
    end

    super
  end

  def install(useversion = true)
    command = [command(:gemcmd), "install"]
    command << "-v" << resource[:ensure] if (! resource[:ensure].is_a? Symbol) and useversion

    if source = resource[:source]
      begin
        uri = URI.parse(source)
      rescue => detail
        self.fail Puppet::Error, "Invalid source '#{uri}': #{detail}", detail
      end

      case uri.scheme
        when nil
          # no URI scheme => interpret the source as a local file
          command << source
        when /file/i
          command << uri.path
        when 'puppet'
          # we don't support puppet:// URLs (yet)
          raise Puppet::Error.new("puppet:// URLs are not supported as gem sources")
        else
          # check whether it's an absolute file path to help Windows out
          if Puppet::Util.absolute_path?(source)
            command << source
          else
            # interpret it as a gem repository
            command << "--source" << "#{source}" << resource[:name]
          end
      end
    else
      command << "--no-rdoc" << "--no-ri" << resource[:name]
    end

    command += install_options if resource[:install_options]

    output = execute(command)
    # Apparently some stupid gem versions don't exit non-0 on failure
    self.fail "Could not install: #{output.chomp}" if output.include?("ERROR")
  end
end
