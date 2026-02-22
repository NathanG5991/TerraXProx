pm_api_url = "https://172.16.0.130:8006/api2/json"
pm_user    = "root@pam"
pm_password = "root1234"
pool_id    = 20
vm_count   = 2
dns_server_ip = "192.168.1.69"
bridge_suffixes = [
  "1",   # donnera vmbrXX1 (ID 1)
  "8",   # donnera vmbrXX8 (ID 2)
  "42",  # donnera vmbrXX42 (ID 3)
  "99",  # donnera vmbrXX99 (ID 4)
  "101", # donnera vmbrXX101 (ID 5)
  "5",   # donnera vmbrXX5 (ID 6)
  "00"   # donnera vmbrXX00 (ID 7)
]
