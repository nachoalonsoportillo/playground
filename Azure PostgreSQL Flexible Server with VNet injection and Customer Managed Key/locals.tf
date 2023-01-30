locals {
  host_os = data.external.os.result.os

  psql_command = "psql \"host=${azurerm_postgresql_flexible_server.pgsql.fqdn} port=5432 dbname=${azurerm_postgresql_flexible_server_database.database.name} user=${azurerm_postgresql_flexible_server.pgsql.administrator_login} password=${azurerm_postgresql_flexible_server.pgsql.administrator_password} sslmode=require\" -c \"DROP TABLE IF EXISTS t1; CREATE TABLE t1 (c1 varchar(20)); INSERT INTO t1 VALUES ('Test Message');SELECT * FROM t1;\""

  ssh_command = "ssh -i ${path.module}/${local_file.key_as_file.filename} ${azurerm_linux_virtual_machine.vm.admin_username}@${azurerm_linux_virtual_machine.vm.public_ip_address}"

  client_ip_address = jsondecode(data.http.current_public_ip.response_body).ip
}