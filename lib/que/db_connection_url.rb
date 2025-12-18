# frozen_string_literal: true

module Que
  class DBConnectionURL
    def self.build_connection_url(db_config)
      # Build base URL
      # Workaround for https://github.com/que-rb/que/issues/442
      connection_url = "#{db_config[:adapter]}://"

      host = db_config[:host]
      is_unix_socket = host && host.start_with?('/')
      is_ipv6 = host && !is_unix_socket && host.include?(':')

      # Add username and password
      connection_url += "#{db_config[:username]}" if db_config[:username]
      connection_url += ":#{db_config[:password]}" if db_config[:password]
      connection_url += "@" if db_config[:username] || db_config[:password]

      # For Unix sockets, leave host empty; for TCP, add host and port
      if is_unix_socket
        connection_url += "/"
      else
        # Wrap IPv6 addresses in square brackets
        formatted_host = is_ipv6 ? "[#{host}]" : (host || 'localhost')
        connection_url += formatted_host
        connection_url += ":#{db_config[:port]}" if db_config[:port]
        connection_url += "/"
      end

      connection_url += db_config[:database]

      # Build query parameters
      params = []

      # For Unix sockets, add host and port as query parameters
      if is_unix_socket
        params << "host=#{host}"
        params << "port=#{db_config[:port]}" if db_config[:port]
      end

      # Add SSL parameters
      params << "sslmode=#{db_config[:sslmode]}" if db_config[:sslmode]
      params << "sslrootcert=#{db_config[:sslrootcert]}" if db_config[:sslrootcert]
      params << "sslcert=#{db_config[:sslcert]}" if db_config[:sslcert]
      params << "sslkey=#{db_config[:sslkey]}" if db_config[:sslkey]

      connection_url += "?#{params.join('&')}" if params.any?

      connection_url
    end
  end
end
