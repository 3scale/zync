# frozen_string_literal: true

require 'test_helper'
require 'que/db_connection_url'

class Que::DBConnectionURLTest < ActiveSupport::TestCase
  test 'minimal configuration' do
    db_config = {
      adapter: 'postgresql',
      database: 'postgres'
    }

    expected = 'postgresql://localhost/postgres'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with port' do
    db_config = {
      adapter: 'postgresql',
      host: 'localhost',
      port: 5432,
      database: 'mydb'
    }

    expected = 'postgresql://localhost:5432/mydb'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with username only' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      host: 'localhost',
      database: 'mydb'
    }

    expected = 'postgresql://user@localhost/mydb'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with empty password' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      password: '',
      host: 'localhost',
      database: 'mydb'
    }

    expected = 'postgresql://user:@localhost/mydb'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with username and password' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      password: 'secret',
      host: 'localhost',
      database: 'database'
    }

    expected = 'postgresql://user:secret@localhost/database'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with password containing special characters' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      password: 'p@ssw0rd!#$',
      host: 'localhost',
      database: 'mydb'
    }

    expected = 'postgresql://user:p@ssw0rd!#$@localhost/mydb'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'full connection with all basic parameters' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      password: 'password',
      host: 'localhost',
      port: 5432,
      database: 'database'
    }

    expected = 'postgresql://user:password@localhost:5432/database'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with different host' do
    db_config = {
      adapter: 'postgresql',
      username: 'username',
      host: 'hostname',
      database: 'databasename'
    }

    expected = 'postgresql://username@hostname/databasename'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with SSL root certificate only' do
    db_config = {
      adapter: 'postgresql',
      host: 'localhost',
      database: 'mydb',
      sslrootcert: '/etc/ssl/certs/ca.crt'
    }

    expected = 'postgresql://localhost/mydb?sslrootcert=/etc/ssl/certs/ca.crt'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with SSL client certificate without mode' do
    db_config = {
      adapter: 'postgresql',
      host: 'localhost',
      database: 'mydb',
      sslcert: '/path/to/cert.crt',
      sslkey: '/path/to/key.key'
    }

    expected = 'postgresql://localhost/mydb?sslcert=/path/to/cert.crt&sslkey=/path/to/key.key'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with all SSL parameters (mTLS)' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      password: 'password',
      host: 'host',
      port: 5432,
      database: 'database',
      sslmode: 'verify-full',
      sslrootcert: '/ca.crt',
      sslcert: '/client.crt',
      sslkey: '/client.key'
    }

    expected = 'postgresql://user:password@host:5432/database?sslmode=verify-full&sslrootcert=/ca.crt&sslcert=/client.crt&sslkey=/client.key'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with IPv6 host' do
    db_config = {
      adapter: 'postgresql',
      host: '::1',
      database: 'database'
    }

    expected = 'postgresql://[::1]/database'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with IPv6 host and port' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      host: '2001:db8::1234',
      port: 5433,
      database: 'database'
    }

    expected = 'postgresql://user@[2001:db8::1234]:5433/database'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with alternative adapter name' do
    db_config = {
      adapter: 'postgres',
      host: 'localhost',
      database: 'mydb'
    }

    expected = 'postgres://localhost/mydb'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'connection with database name containing underscores' do
    db_config = {
      adapter: 'postgresql',
      username: 'postgres',
      password: 'secret',
      host: 'localhost',
      database: 'test_db'
    }

    expected = 'postgresql://postgres:secret@localhost/test_db'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'production-like configuration with SSL' do
    db_config = {
      adapter: 'postgresql',
      username: 'app_user',
      password: 'secure_password',
      host: 'db.example.com',
      port: 5432,
      database: 'production_db',
      sslmode: 'verify-full',
      sslrootcert: '/etc/ssl/certs/server-ca.pem',
      sslcert: '/etc/ssl/certs/client-cert.pem',
      sslkey: '/etc/ssl/private/client-key.pem'
    }

    expected = 'postgresql://app_user:secure_password@db.example.com:5432/production_db?sslmode=verify-full&sslrootcert=/etc/ssl/certs/server-ca.pem&sslcert=/etc/ssl/certs/client-cert.pem&sslkey=/etc/ssl/private/client-key.pem'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'OpenShift-like configuration' do
    db_config = {
      adapter: 'postgresql',
      username: 'zync',
      password: 'zync-password',
      host: 'postgresql.example.svc.cluster.local',
      port: 5432,
      database: 'zync_production',
      sslmode: 'require',
      sslrootcert: '/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt'
    }

    expected = 'postgresql://zync:zync-password@postgresql.example.svc.cluster.local:5432/zync_production?sslmode=require&sslrootcert=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  # Unix socket connections
  test 'Unix socket with default socket directory' do
    db_config = {
      adapter: 'postgresql',
      database: 'mydb',
      host: '/var/run/postgresql'
    }

    expected = 'postgresql:///mydb?host=/var/run/postgresql'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'Unix socket with username' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      database: 'mydb',
      host: '/var/run/postgresql'
    }

    expected = 'postgresql://user@/mydb?host=/var/run/postgresql'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'Unix socket with username and password' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      password: 'password',
      database: 'mydb',
      host: '/var/run/postgresql'
    }

    expected = 'postgresql://user:password@/mydb?host=/var/run/postgresql'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'Unix socket with custom socket directory' do
    db_config = {
      adapter: 'postgresql',
      username: 'postgres',
      database: 'development',
      host: '/opt/postgresql/run'
    }

    expected = 'postgresql://postgres@/development?host=/opt/postgresql/run'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'Unix socket with port parameter' do
    db_config = {
      adapter: 'postgresql',
      database: 'mydb',
      host: '/var/run/postgresql',
      port: 5433
    }

    expected = 'postgresql:///mydb?host=/var/run/postgresql&port=5433'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'Unix socket with SSL parameters' do
    db_config = {
      adapter: 'postgresql',
      username: 'user',
      database: 'mydb',
      host: '/var/run/postgresql',
      sslmode: 'require'
    }

    expected = 'postgresql://user@/mydb?host=/var/run/postgresql&sslmode=require'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end

  test 'Unix socket with all parameters' do
    db_config = {
      adapter: 'postgresql',
      username: 'appuser',
      password: 'secret',
      database: 'production_db',
      host: '/var/run/postgresql',
      port: 5432,
    }

    expected = 'postgresql://appuser:secret@/production_db?host=/var/run/postgresql&port=5432'
    assert_equal expected, Que::DBConnectionURL.build_connection_url(db_config)
  end
end
