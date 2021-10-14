# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output "project_id" {
  value = var.project_id
}

output "instances_self_links_master" {
  value = module.sap_hana_instance_master.instances_self_links
}

output "instances_self_links_worker" {
  value = concat(flatten(module.sap_hana_instance_worker.*.instances_self_links), flatten(module.sap_hana_instance_standby.*.instances_self_links))
}

output "master_instance_name" {
  value = element(split("/", element(tolist(module.sap_hana_instance_master.instances_self_links), 0)), 10)
}

output "worker_instance_names" {
  value       = [
    for link in flatten(module.sap_hana_instance_worker.*.instances_self_links) : split("/", link)[10]
  ]
}

output "address_master" {
  value = google_compute_address.gcp_sap_hana_intip_master.*.address
}

output "address_worker" {
  value = google_compute_address.gcp_sap_hana_intip_worker.*.address
}

output "master_attached_disks_data" {
  value = google_compute_attached_disk.master_data.*.disk
}

output "worker_attached_disks_data" {
  value = google_compute_attached_disk.worker_data.*.disk
}

output "hana_data_size" {
  value = local.hana_data_size
}

output "hana_log_size" {
  value = local.hana_log_size
}

output "hana_usr_size" {
  value = local.hana_usr_size
}

output "inventory" {
  value = {
    hana = concat(
      google_compute_address.gcp_sap_hana_intip_master.*.address,
      google_compute_address.gcp_sap_hana_intip_worker.*.address,
      google_compute_address.gcp_sap_hana_intip_standby.*.address,
    )
    hana-master = google_compute_address.gcp_sap_hana_intip_master.*.address
    hana-worker = concat(
      google_compute_address.gcp_sap_hana_intip_worker.*.address,
      google_compute_address.gcp_sap_hana_intip_standby.*.address,
    )
  }
}

output "hana_filestore_backup" {
  value = "${google_filestore_instance.hana_filestore_backup.networks[0].ip_addresses[0]}:/${google_filestore_instance.hana_filestore_backup.file_shares[0].name}"
}

output "hana_filestore_shared" {
  value = "${google_filestore_instance.hana_filestore_shared.networks[0].ip_addresses[0]}:/${google_filestore_instance.hana_filestore_shared.file_shares[0].name}"
}