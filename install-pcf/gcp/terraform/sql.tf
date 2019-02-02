resource "random_pet" "sql_db" {
  length = 1
}

resource "google_sql_database_instance" "master" {
  region           = "${var.gcp_region}"
  database_version = "MYSQL_5_6"
  name             = "${var.prefix}-${random_pet.sql_db.id}"

  settings {
    tier = "${var.db_cloudsqldb_tier}"

    ip_configuration = {
      ipv4_enabled = true

      authorized_networks = [
        {
          name  = "nat-1"
          value = "${google_compute_instance.nat-gateway-pri.network_interface.0.access_config.0.assigned_nat_ip}"
        },
        {
          name  = "nat-2"
          value = "${google_compute_instance.nat-gateway-sec.network_interface.0.access_config.0.assigned_nat_ip}"
        },
        {
          name  = "nat-3"
          value = "${google_compute_instance.nat-gateway-ter.network_interface.0.access_config.0.assigned_nat_ip}"
        },
        {
          name  = "opsman"
          value = "${google_compute_instance.ops-manager.network_interface.0.access_config.0.assigned_nat_ip}"
        },
      ]
    }
  }
}

resource "google_sql_database" "uaa" {
  name     = "uaa"
  instance = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "ccdb" {
  name       = "ccdb"
  depends_on = ["google_sql_database.uaa"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "notifications" {
  name       = "notifications"
  depends_on = ["google_sql_database.ccdb"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "autoscale" {
  name       = "autoscale"
  depends_on = ["google_sql_database.notifications"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "app_usage_service" {
  name       = "app_usage_service"
  depends_on = ["google_sql_database.autoscale"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "console" {
  name       = "console"
  depends_on = ["google_sql_database.app_usage_service"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "routing" {
  name       = "routing"
  depends_on = ["google_sql_database.console"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "diego" {
  name       = "diego"
  depends_on = ["google_sql_database.routing"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "account" {
  name       = "account"
  depends_on = ["google_sql_database.diego"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "nfsvolume" {
  name       = "nfsvolume"
  depends_on = ["google_sql_database.account"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "networkpolicyserver" {
  name       = "networkpolicyserver"
  depends_on = ["google_sql_database.nfsvolume"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "locket" {
  name       = "locket"
  depends_on = ["google_sql_database.networkpolicyserver"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "credhub" {
  name       = "credhub"
  depends_on = ["google_sql_database.networkpolicyserver"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_database" "silk" {
  name       = "silk"
  depends_on = ["google_sql_database.locket"]
  instance   = "${google_sql_database_instance.master.name}"
}

resource "google_sql_user" "credhub" {
  name       = "${var.db_credhub_username}"
  password   = "${var.db_credhub_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_database.credhub"]
}

resource "google_sql_user" "diego" {
  name       = "${var.db_diego_username}"
  password   = "${var.db_diego_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_database.silk"]
}

resource "google_sql_user" "notifications" {
  name       = "${var.db_notifications_username}"
  password   = "${var.db_notifications_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.diego"]
}

resource "google_sql_user" "autoscale" {
  name       = "${var.db_autoscale_username}"
  password   = "${var.db_autoscale_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.notifications"]
}

resource "google_sql_user" "uaa" {
  name       = "${var.db_uaa_username}"
  password   = "${var.db_uaa_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.autoscale"]
}

resource "google_sql_user" "app_usage_service" {
  name       = "${var.db_app_usage_service_username}"
  password   = "${var.db_app_usage_service_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.uaa"]
}

resource "google_sql_user" "ccdb" {
  name       = "${var.db_ccdb_username}"
  password   = "${var.db_ccdb_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.app_usage_service"]
}

resource "google_sql_user" "routing" {
  name       = "${var.db_routing_username}"
  password   = "${var.db_routing_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.ccdb"]
}

resource "google_sql_user" "account" {
  name       = "${var.db_accountdb_username}"
  password   = "${var.db_accountdb_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.routing"]
}

resource "google_sql_user" "network_policy_server" {
  name       = "${var.db_networkpolicyserverdb_username}"
  password   = "${var.db_networkpolicyserverdb_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.account"]
}

resource "google_sql_user" "nfs_volume" {
  name       = "${var.db_nfsvolumedb_username}"
  password   = "${var.db_nfsvolumedb_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.network_policy_server"]
}

resource "google_sql_user" "locket" {
  name       = "${var.db_locket_username}"
  password   = "${var.db_locket_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.nfs_volume"]
}

resource "google_sql_user" "silk" {
  name       = "${var.db_silk_username}"
  password   = "${var.db_silk_password}"
  instance   = "${google_sql_database_instance.master.name}"
  host       = "%"
  depends_on = ["google_sql_user.locket"]
}
