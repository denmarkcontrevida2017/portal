module MaziNetwork
  def get_interfaces
    interfaces = {}
    ex = MaziExecCmd.new('bash', '/root/back-end/', 'current.sh', ['-i', 'all', '-i', 'wifi', '-i', 'internet', '-i', 'mesh'], @config[:scripts][:enabled_scripts])
    lines = ex.exec_command
    wifi_if     = nil
    internet_if = nil
    mesh_if     = nil
    ex.parseForAll('interface').each do |ifc|
      case ifc.first
      when 'interface'
        interfaces[ifc[1].to_sym]             = {}
        interfaces[ifc[1].to_sym][:interface] = ifc[1]
        interfaces[ifc[1].to_sym][:name]      = ifc[2] == 'raspberry' ? 'Raspberry WiFi' : "#{ifc[2].upcase} WiFi"
        interfaces[ifc[1].to_sym][:mode]      = nil
      when 'wifi_interface'
        wifi_if = ifc[1] == '-' ? nil : ifc[1].to_sym
      when 'internet_interface'
        internet_if = ifc[1] == '-' ? nil : ifc[1].to_sym
      when 'mesh_interface'
        mesh_if = ifc[1] == '-' ? nil : ifc[1].to_sym
      end
    end
    interfaces[wifi_if][:mode] = 'wifi' unless wifi_if.nil? || interfaces[wifi_if].nil?
    interfaces[internet_if][:mode] = 'internet' unless internet_if.nil? || interfaces[internet_if].nil?
    interfaces[mesh_if][:mode] = 'mesh' unless mesh_if.nil? || interfaces[mesh_if].nil?

    interfaces
  end

  def populate_interfaces(interfaces)
    interfaces.each do |if_name, if_data|
      case if_data[:mode]
      when 'wifi'
        ex1 = MaziExecCmd.new('bash', '/root/back-end/', 'current.sh', ['-s', '-p', '-c'], @config[:scripts][:enabled_scripts])
        lines = ex1.exec_command
        ssid = ex1.parseFor('ssid')
        ssid.shift
        if_data[:ssid] = ssid.join(' ') if ssid.kind_of? Array
        channel = ex1.parseFor('channel')
        if_data[:channel] = channel[1] if channel.kind_of? Array
        password = ex1.parseFor('password')
        if_data[:password] = password[1] if password.kind_of? Array
        ap = if_name
      when 'internet'
        ex2 = MaziExecCmd.new('bash', '/root/back-end/', 'antenna.sh', ['-i', if_name.to_s, '-a'], @config[:scripts][:enabled_scripts])
        lines = ex2.exec_command
        if lines.nil? || lines.empty? || !lines.first.include?('ESSID')
          if_data[:mode] = nil
          session['error'] = "Interface #{if_name} has not been configured properly. Please make sure the details that you have provided are correct."
          `ifconfig #{if_name} down`
          `ifconfig #{if_name} up`
          `bash /root/back-end/antenna.sh -i #{if_name} -d`
          redirect "/admin_network"
        end
        ssid = ex2.parseFor('ESSID')
        if_data[:ssid] = ssid.last.split(':').last.gsub('"', '')
        if_data[:available_ssids] = []
        ex7 = MaziExecCmd.new('bash', '/root/back-end/', 'antenna.sh', ['-l', '-i', if_name], @config[:scripts][:enabled_scripts])
        if_data[:available_ssids] = ex7.exec_command
        if_data[:available_ssids].map! {|ssid| ssid.gsub('ESSID:', '').gsub('"', '')}
        if_data[:available_ssids].reject! {|ssid| ssid.empty?}
      when 'mesh'

      else
        if_data[:available_ssids] = []
        ex8 = MaziExecCmd.new('bash', '/root/back-end/', 'antenna.sh', ['-l', '-i', if_name], @config[:scripts][:enabled_scripts])
        if_data[:available_ssids] = ex8.exec_command
        if_data[:available_ssids].map! {|ssid| ssid.gsub('ESSID:', '').gsub('"', '')}
        if_data[:available_ssids].reject! {|ssid| ssid.empty?}
      end
    end
    interfaces
  end

  def verify_domain(domain)
    return "contain at least one dot (.) character" unless domain.include?('.')
    return "not contain a hyphen (-) as the first or the last character" if domain.start_with?('-') || domain.end_with?('-')
    special = "?<>',?[]}{=_)(*&^%$#`~{}"
    regex = /[#{special.gsub(/./){|char| "\\#{char}"}}]/
    return "not contain the following characters: #{special}" if domain =~ regex
    nil
  end
end
